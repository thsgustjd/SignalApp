//
//  RoomMembersSupport.swift
//  SignalApp
//

import Foundation

struct RoomMember: Codable, Identifiable, Equatable {
    let id: UUID
    let roomId: UUID
    let userId: String
    let displayName: String
    let joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case userId = "user_id"
        case displayName = "display_name"
        case joinedAt = "joined_at"
    }
}

private struct RoomMemberInsert: Encodable {
    let roomId: UUID
    let userId: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case userId = "user_id"
        case displayName = "display_name"
    }
}

private struct RoomMemberUserPatch: Encodable {
    let userId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

private struct RoomMemberNamePatch: Encodable {
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

extension SupabaseManager {
    static let roomMaxMembers = 5
    /// 한 사용자가 동시에 참여할 수 있는 서로 다른 방 수.
    static let userMaxJoinedRooms = 5

    func activeMemberCount(for room: Room) -> Int {
        if !room.members.isEmpty { return room.members.count }
        return legacySlotMemberCount(for: room)
    }

    func memberCapacity(for room: Room) -> Int {
        Self.roomMaxMembers
    }

    func legacySlotMemberCount(for room: Room) -> Int {
        var count = 0
        if !room.user1Id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if let user2 = room.user2Id?.trimmingCharacters(in: .whitespacesAndNewlines), !user2.isEmpty { count += 1 }
        return count
    }

    func memberCountLabel(for room: Room) -> String {
        "\(activeMemberCount(for: room))/\(memberCapacity(for: room))명"
    }

    func normalizedRoomDisplayName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func member(matchingDisplayName nickname: String, in room: Room) -> RoomMember? {
        let nick = normalizedRoomDisplayName(nickname)
        guard !nick.isEmpty else { return nil }
        return room.members.first { normalizedRoomDisplayName($0.displayName) == nick }
    }

    /// 초대 코드만 맞으면 멤버로 들어갑니다 (닉네임·재입장 매칭 없음).
    func ensureJoinedRoom(_ existing: Room) async throws -> Room {
        try await bootstrapMembershipIfNeeded(for: existing)
        var room = try await refreshRoom(id: existing.id)

        if isCurrentUserMember(of: room) {
            return room
        }

        try await assertCanJoinAdditionalRoom()

        if activeMemberCount(for: room) >= memberCapacity(for: room) {
            throw SupabaseManagerError.roomAlreadyFull
        }

        let displayName = defaultMemberDisplayName()
        try await insertMember(roomId: room.id, userId: currentUserId, displayName: displayName)

        let members = try await fetchMembers(roomId: room.id)
        if members.count == 2, isUser2SlotEmpty(in: room) {
            _ = try? await client
                .from("rooms")
                .update(JoinRoomPayload(user2Id: currentUserId, user2Name: displayName), returning: .minimal)
                .eq("id", value: room.id)
                .execute()
        }

        return try await refreshRoom(id: room.id)
    }

    /// 같은 방(`room`) 안에서 닉네임 중복 여부. `excludingMemberId`는 본인 멤버 row 이름 변경 시 제외.
    func isDisplayNameTaken(in room: Room, displayName: String, excludingMemberId: UUID? = nil) -> Bool {
        let nick = normalizedRoomDisplayName(displayName)
        guard !nick.isEmpty else { return false }

        if room.members.contains(where: { member in
            if member.id == excludingMemberId { return false }
            return normalizedRoomDisplayName(member.displayName) == nick
        }) {
            return true
        }

        if room.members.isEmpty {
            if nick == normalizedRoomDisplayName(room.user1Name ?? "") { return true }
            if nick == normalizedRoomDisplayName(room.user2Name ?? "") { return true }
        }

        return false
    }

    func recipientUserIds(in room: Room, excluding senderId: String) -> [String] {
        if !room.members.isEmpty {
            return room.members
                .map(\.userId)
                .filter { !DeviceUserId.matches($0, senderId) }
        }
        var ids: [String] = []
        if !room.user1Id.isEmpty, !DeviceUserId.matches(room.user1Id, senderId) {
            ids.append(room.user1Id)
        }
        if let user2 = room.user2Id?.trimmingCharacters(in: .whitespacesAndNewlines),
           !user2.isEmpty,
           !DeviceUserId.matches(user2, senderId) {
            ids.append(user2)
        }
        return ids
    }

    func memberDisplayName(userId: String, in room: Room) -> String? {
        if let member = room.members.first(where: { DeviceUserId.matches($0.userId, userId) }) {
            let name = member.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
        if DeviceUserId.matches(room.user1Id, userId),
           let name = room.user1Name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        if let user2 = room.user2Id, DeviceUserId.matches(user2, userId),
           let name = room.user2Name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        return nil
    }

    /// 채팅방 제목용 — 참가자 전원 표시 이름 (본인 포함, ` · 나` 없음).
    func allParticipantDisplayNames(in room: Room) -> [String] {
        if !room.members.isEmpty {
            return room.members.compactMap { member in
                let trimmed = member.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        }
        var names: [String] = []
        if let n1 = room.user1Name?.trimmingCharacters(in: .whitespacesAndNewlines), !n1.isEmpty {
            names.append(n1)
        }
        if let n2 = room.user2Name?.trimmingCharacters(in: .whitespacesAndNewlines), !n2.isEmpty {
            names.append(n2)
        }
        return names
    }

    /// 채팅방 상단 「참여 중」 목록용 (본인 포함).
    func participantDisplayLabels(in room: Room) -> [String] {
        let myId = currentUserId
        if !room.members.isEmpty {
            return room.members.map { member in
                let trimmed = member.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = trimmed.isEmpty ? "member" : trimmed
                if DeviceUserId.matches(member.userId, myId) {
                    return "\(name) · 나"
                }
                return name
            }
        }
        var labels: [String] = []
        if let n1 = room.user1Name?.trimmingCharacters(in: .whitespacesAndNewlines), !n1.isEmpty {
            labels.append(DeviceUserId.matches(room.user1Id, myId) ? "\(n1) · 나" : n1)
        }
        if let user2 = room.user2Id,
           let n2 = room.user2Name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !n2.isEmpty {
            labels.append(DeviceUserId.matches(user2, myId) ? "\(n2) · 나" : n2)
        }
        return labels
    }

    func otherMemberDisplayNames(in room: Room) -> [String] {
        let myId = currentUserId
        if !room.members.isEmpty {
            return room.members
                .filter { !DeviceUserId.matches($0.userId, myId) }
                .map(\.displayName)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        var names: [String] = []
        if !DeviceUserId.matches(room.user1Id, myId),
           let name = room.user1Name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            names.append(name)
        }
        if let user2 = room.user2Id,
           !DeviceUserId.matches(user2, myId),
           let name = room.user2Name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            names.append(name)
        }
        return names
    }

    func chatShowsSenderNames(for room: Room) -> Bool {
        activeMemberCount(for: room) >= 3
    }

    func isRoomCreator(_ room: Room) -> Bool {
        DeviceUserId.matches(room.user1Id, currentUserId)
    }

    func isUser2SlotEmpty(in room: Room) -> Bool {
        guard let raw = room.user2Id?.trimmingCharacters(in: .whitespacesAndNewlines) else { return true }
        return raw.isEmpty
    }

    func bootstrapMembershipIfNeeded(for room: Room) async throws {
        var hydrated = try await hydrateRoom(room)
        if !hydrated.members.isEmpty { return }

        try await backfillMembersFromLegacyRoom(room)
        if hydrated.members.isEmpty,
           !room.user1Id.isEmpty,
           DeviceUserId.matches(room.user1Id, currentUserId) {
            try await insertMember(
                roomId: room.id,
                userId: room.user1Id,
                displayName: room.user1Name ?? savedNickname ?? "member"
            )
        }
    }

    func fetchMembers(roomId: UUID) async throws -> [RoomMember] {
        try await client
            .from(RoomMemberSchema.table)
            .select(RoomMemberSchema.selectList)
            .eq("room_id", value: roomId)
            .order("joined_at", ascending: true)
            .execute()
            .value
    }

    func hydrateRoom(_ room: Room) async throws -> Room {
        var copy = room
        do {
            copy.members = try await fetchMembers(roomId: room.id)
            if copy.members.isEmpty {
                try? await backfillMembersFromLegacyRoom(room)
                copy.members = try await fetchMembers(roomId: room.id)
            }
        } catch {
            print("⚠️ [RoomMembers] unavailable — run Docs/supabase/RoomMembersSetup.sql: \(error.localizedDescription)")
            copy.members = []
        }
        return copy
    }

    private func backfillMembersFromLegacyRoom(_ room: Room) async throws {
        let name: (String?) -> String = {
            let t = $0?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? "member" : t
        }
        if !room.user1Id.isEmpty {
            try await insertMember(roomId: room.id, userId: room.user1Id, displayName: name(room.user1Name))
        }
        if let user2 = room.user2Id?.trimmingCharacters(in: .whitespacesAndNewlines), !user2.isEmpty {
            try await insertMember(roomId: room.id, userId: user2, displayName: name(room.user2Name))
        }
    }

    func insertMember(roomId: UUID, userId: String, displayName: String) async throws {
        let payload = RoomMemberInsert(roomId: roomId, userId: userId, displayName: displayName)
        do {
            _ = try await client
                .from(RoomMemberSchema.table)
                .insert(payload, returning: .minimal)
                .execute()
        } catch {
            print("ℹ️ [RoomMembers] insert skip: \(error.localizedDescription)")
        }
    }

    func updateMemberUserId(memberId: UUID, userId: String) async throws {
        try await client
            .from(RoomMemberSchema.table)
            .update(RoomMemberUserPatch(userId: userId))
            .eq("id", value: memberId)
            .execute()
    }

    func updateMemberDisplayName(memberId: UUID, displayName: String) async throws {
        try await client
            .from(RoomMemberSchema.table)
            .update(RoomMemberNamePatch(displayName: displayName))
            .eq("id", value: memberId)
            .execute()
    }

    func updateMyMemberDisplayName(in room: Room, nickname: String) async throws {
        let myId = currentUserId
        guard let member = room.members.first(where: { DeviceUserId.matches($0.userId, myId) }) else { return }
        let trimmed = normalizedRoomDisplayName(nickname)
        guard normalizedRoomDisplayName(member.displayName) != trimmed else { return }
        try await updateMemberDisplayName(memberId: member.id, displayName: trimmed)
    }

    func addCreatorMember(room: Room, nickname: String) async throws {
        try await insertMember(roomId: room.id, userId: currentUserId, displayName: nickname)
    }

    func fetchRoomIdsForCurrentUser() async -> [UUID] {
        let userId = currentUserId
        var ids = Set<UUID>()
        let variants = Array(Set([userId, userId.uppercased()]))

        for variant in variants {
            do {
                let rows: [RoomMember] = try await client
                    .from(RoomMemberSchema.table)
                    .select(RoomMemberSchema.selectList)
                    .eq("user_id", value: variant)
                    .limit(50)
                    .execute()
                    .value
                for row in rows where DeviceUserId.matches(row.userId, userId) {
                    ids.insert(row.roomId)
                }
            } catch {
                print("⚠️ [RoomMembers] list by user_id failed: \(error.localizedDescription)")
            }
        }
        return Array(ids)
    }
}
