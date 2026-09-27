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

    func joinRoomMembers(existing: Room, nickname: String) async throws -> Room {
        let room = try await hydrateRoom(existing)

        if let member = room.members.first(where: { DeviceUserId.matches($0.userId, currentUserId) }) {
            if member.displayName != nickname {
                try await updateMemberDisplayName(memberId: member.id, displayName: nickname)
            }
            return try await refreshRoom(id: room.id)
        }

        if let memberByName = room.members.first(where: { $0.displayName == nickname }) {
            try await updateMemberUserId(memberId: memberByName.id, userId: currentUserId)
            return try await refreshRoom(id: room.id)
        }

        guard activeMemberCount(for: room) < memberCapacity(for: room) else {
            throw SupabaseManagerError.roomAlreadyFull
        }

        try await insertMember(roomId: room.id, userId: currentUserId, displayName: nickname)

        let members = try await fetchMembers(roomId: room.id)
        if members.count == 2, isUser2SlotEmpty(in: room) {
            _ = try? await client
                .from("rooms")
                .update(JoinRoomPayload(user2Id: currentUserId, user2Name: nickname), returning: .minimal)
                .eq("id", value: room.id)
                .execute()
        }

        return try await refreshRoom(id: room.id)
    }

    func updateMyMemberDisplayName(in room: Room, nickname: String) async throws {
        let myId = currentUserId
        guard let member = room.members.first(where: { DeviceUserId.matches($0.userId, myId) }) else { return }
        guard member.displayName != nickname else { return }
        try await updateMemberDisplayName(memberId: member.id, displayName: nickname)
    }

    func addCreatorMember(room: Room, nickname: String) async throws {
        try await insertMember(roomId: room.id, userId: currentUserId, displayName: nickname)
    }

    func alignMemberUserIdIfNeeded(_ room: Room) async throws -> Room {
        try await bootstrapMembershipIfNeeded(for: room)
        var hydrated = try await hydrateRoom(room)
        if isCurrentUserMember(of: hydrated) { return hydrated }

        guard let nick = savedNickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nick.isEmpty else {
            return hydrated
        }

        if let member = hydrated.members.first(where: { $0.displayName == nick }) {
            try await updateMemberUserId(memberId: member.id, userId: currentUserId)
            return try await refreshRoom(id: room.id)
        }

        if hydrated.user1Name == nick {
            let updated = try await rejoinAsUser1(existing: hydrated)
            try await backfillMembersFromLegacyRoom(updated)
            return try await refreshRoom(id: room.id)
        }

        return hydrated
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
                for row in rows { ids.insert(row.roomId) }
            } catch {
                print("⚠️ [RoomMembers] list by user_id failed: \(error.localizedDescription)")
            }
        }
        return Array(ids)
    }
}
