//
//  SupabaseManager.swift
//  SignalApp
//

import Foundation
import Supabase
import WidgetKit

enum SupabaseManagerError: LocalizedError {
    case roomNotFound
    case roomAlreadyFull
    case invalidInviteCode
    case invalidNickname
    case emptyMediaData
    case roomDeleteNotAllowed

    var errorDescription: String? {
        switch self {
        case .roomNotFound:
            return "해당 초대 코드의 방을 찾을 수 없습니다."
        case .roomAlreadyFull:
            return "이 방은 최대 5명까지 참여할 수 있습니다. 등록한 닉네임으로 재입장해 주세요."
        case .invalidInviteCode:
            return "12자리 초대 코드를 입력해 주세요."
        case .invalidNickname:
            return "닉네임은 영문·숫자만 사용할 수 있습니다 (공백/특수문자 불가)."
        case .emptyMediaData:
            return "업로드할 미디어 데이터가 비어 있습니다."
        case .roomDeleteNotAllowed:
            return "혼자만 있는 대기 방만 삭제할 수 있습니다. 멤버가 2명 이상이면 채팅방 메뉴에서 나가기를 사용해 주세요."
        }
    }
}

struct MediaMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let roomId: UUID
    let type: String
    let senderId: String
    let senderNickname: String?
    let mediaUrl: String?
    let content: String?
    let createdAt: Date
    let isRead: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case type
        case senderId = "sender_id"
        case senderNickname = "sender_nickname"
        case mediaUrl = "media_url"
        case content
        case createdAt = "created_at"
        case isRead = "is_read"
    }

    init(
        id: UUID,
        roomId: UUID,
        type: String,
        senderId: String,
        senderNickname: String?,
        mediaUrl: String?,
        content: String?,
        createdAt: Date,
        isRead: Bool = false
    ) {
        self.id = id
        self.roomId = roomId
        self.type = type
        self.senderId = senderId
        self.senderNickname = senderNickname
        self.mediaUrl = mediaUrl
        self.content = content
        self.createdAt = createdAt
        self.isRead = isRead
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        roomId = try container.decode(UUID.self, forKey: .roomId)
        type = try container.decode(String.self, forKey: .type)
        senderId = try container.decode(String.self, forKey: .senderId)
        senderNickname = try container.decodeIfPresent(String.self, forKey: .senderNickname)
        mediaUrl = try container.decodeIfPresent(String.self, forKey: .mediaUrl)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
    }
}

struct Room: Codable, Identifiable, Equatable {
    let id: UUID
    let inviteCode: String
    let user1Id: String
    let user2Id: String?
    let user1Name: String?
    let user2Name: String?
    var members: [RoomMember] = []

    enum CodingKeys: String, CodingKey {
        case id
        case inviteCode = "invite_code"
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case user1Name = "user1_name"
        case user2Name = "user2_name"
    }

    init(
        id: UUID,
        inviteCode: String,
        user1Id: String,
        user2Id: String? = nil,
        user1Name: String? = nil,
        user2Name: String? = nil,
        members: [RoomMember] = []
    ) {
        self.id = id
        self.inviteCode = inviteCode
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.user1Name = user1Name
        self.user2Name = user2Name
        self.members = members
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        inviteCode = try container.decode(String.self, forKey: .inviteCode)
        user1Id = try container.decode(String.self, forKey: .user1Id)
        user2Id = try container.decodeIfPresent(String.self, forKey: .user2Id)
        user1Name = try container.decodeIfPresent(String.self, forKey: .user1Name)
        user2Name = try container.decodeIfPresent(String.self, forKey: .user2Name)
        members = []
    }

    var isMatched: Bool {
        if !members.isEmpty { return members.count >= 2 }
        guard let user2Id else { return false }
        return !user2Id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct NewRoomPayload: Encodable {
    let inviteCode: String
    let user1Id: String
    let user1Name: String

    enum CodingKeys: String, CodingKey {
        case inviteCode = "invite_code"
        case user1Id = "user1_id"
        case user1Name = "user1_name"
    }
}

struct JoinRoomPayload: Encodable {
    let user2Id: String
    let user2Name: String

    enum CodingKeys: String, CodingKey {
        case user2Id = "user2_id"
        case user2Name = "user2_name"
    }
}

private struct RejoinUser1Payload: Encodable {
    let user1Id: String

    enum CodingKeys: String, CodingKey {
        case user1Id = "user1_id"
    }
}

private struct RejoinUser2Payload: Encodable {
    let user2Id: String

    enum CodingKeys: String, CodingKey {
        case user2Id = "user2_id"
    }
}

private struct MediaMessageInsert: Encodable {
    let roomId: UUID
    let type: String
    let senderId: String
    let senderNickname: String
    let mediaUrl: String?
    let content: String?
    let isRead: Bool

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case type
        case senderId = "sender_id"
        case senderNickname = "sender_nickname"
        case mediaUrl = "media_url"
        case content
        case isRead = "is_read"
    }

    init(
        roomId: UUID,
        type: String,
        senderId: String,
        senderNickname: String,
        mediaUrl: String?,
        content: String?,
        isRead: Bool = false
    ) {
        self.roomId = roomId
        self.type = type
        self.senderId = senderId
        self.senderNickname = senderNickname
        self.mediaUrl = mediaUrl
        self.content = content
        self.isRead = isRead
    }
}

private struct MessageReadPatch: Encodable {
    let isRead: Bool

    enum CodingKeys: String, CodingKey {
        case isRead = "is_read"
    }

    init() {
        isRead = true
    }
}

final class SupabaseManager {
    static let shared = SupabaseManager()

    private enum Constants {
        static let userDefaultsKey = "signal_app_device_user_id"
        static let nicknameDefaultsKey = "signal_app_nickname"
        static let skipRoomAutoLoadKey = "signal_skip_room_auto_load"
        static let knownRoomIdsKey = "signal_known_room_ids"
        static let lastRoomIdKey = "signal_last_room_id"
        static let lastInviteCodeKey = "signal_last_invite_code"
        static let lastAPNSTokenKey = "signal_apns_token_hex"
        static let mediaBucket = SignalSupabaseConfig.mediaStorageBucket
        static let chatMessageTypes: Set<String> = ["emoji", "photo", "drawing"]
        static let matchPollInterval: Duration = .seconds(3)
        static let inviteCodeLength = 12
    }

    private static let inviteCharacters = Array(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    )

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SignalSupabaseConfig.url,
            supabaseKey: SignalSupabaseConfig.publishableKey
        )
    }

    var currentUserId: String {
        if let existing = UserDefaults.standard.string(forKey: Constants.userDefaultsKey) {
            let canonical = DeviceUserId.canonical(existing)
            if canonical != existing {
                UserDefaults.standard.set(canonical, forKey: Constants.userDefaultsKey)
            }
            AppGroupStorage.syncUserId(canonical)
            return canonical
        }
        let newId = DeviceUserId.canonical(UUID().uuidString)
        UserDefaults.standard.set(newId, forKey: Constants.userDefaultsKey)
        AppGroupStorage.syncUserId(newId)
        return newId
    }

    /// Edge Function이 **이 기기**에 푸시할 때 `profiles.id`로 쓰는 값 (DB에 저장된 `user_id` 문자열 그대로).
    func edgeRecipientIdForThisDevice(in room: Room) -> String? {
        let myId = currentUserId
        if let member = room.members.first(where: { DeviceUserId.matches($0.userId, myId) }) {
            return member.userId
        }
        if DeviceUserId.matches(room.user1Id, myId) { return room.user1Id }
        if let user2 = room.user2Id, !user2.isEmpty, DeviceUserId.matches(user2, myId) {
            return user2
        }
        return nil
    }

    /// `profiles.id` 저장값 ↔ Edge `recipient_id` 일치 여부 디버그 (전체 UUID 출력).
    func logPushRecipientIdAlignment(context: String) async {
        let local = currentUserId
        let localUUID = UUID(uuidString: local)
        print(
            """
            🔗 [Push-ID] === \(context) ===
            currentUserId (로컬, lowercase UUID)=\(local)
            UUID 파싱=\(localUUID != nil ? "OK" : "FAIL") hyphens=\(local.contains("-"))
            """
        )

        guard let roomId = lastPersistedRoomId, let room = try? await refreshRoom(id: roomId) else {
            print("🔗 [Push-ID] persisted room 없음 → profiles.id는 sender_id/device id와 동일해야 Edge 조회 가능")
            return
        }

        let edgeSelf = edgeRecipientIdForThisDevice(in: room)
        let partner = partnerUserId(in: room)
        let inRoom = edgeSelf != nil

        print(
            """
            🔗 [Push-ID] rooms.user1_id=\(room.user1Id)
            🔗 [Push-ID] rooms.user2_id=\(room.user2Id ?? "nil")
            🔗 [Push-ID] 나에게 넛지 시 Edge recipient_id (DB 문자열 그대로)=\(edgeSelf ?? "⚠️ MISMATCH")
            🔗 [Push-ID] profiles에 반드시 있어야 할 id=\(edgeSelf ?? local)
            🔗 [Push-ID] local == rooms 내 id (exact)=\(local == edgeSelf) (caseInsensitive match=\(inRoom))
            🔗 [Push-ID] 상대에게 보낼 때 Edge recipient_id=\(partner ?? "nil")
            """
        )

        if !inRoom {
            print("🔴 [Push-ID] currentUserId가 rooms.user1/user2와 다름 — 재입장하지 않으면 profile_row_found=false")
        }

        let probeId = edgeSelf ?? local
        if let row = await fetchProfileRow(profileId: probeId) {
            let hasToken = !(row.apnsToken?.isEmpty ?? true)
            print("🔗 [Push-ID] DB profiles.id=\(row.id) exists apns_token=\(hasToken ? "SET" : "EMPTY")")
            if row.id != probeId {
                print("⚠️ [Push-ID] DB id 문자열=\(row.id) vs Edge key=\(probeId) (대소문자 차이)")
            }
        } else {
            print("🔴 [Push-ID] DB profiles 행 없음 lookupKey=\(probeId)")
        }
    }

    /// 1:1 방에서 상대 device user id (`profiles.id` / `messages.sender_id` — Supabase Auth UUID 아님).
    func partnerUserId(in room: Room) -> String? {
        let others = recipientUserIds(in: room, excluding: currentUserId)
        return others.first
    }

    func isCurrentUserMember(of room: Room) -> Bool {
        let myId = currentUserId
        if !room.members.isEmpty {
            return room.members.contains { DeviceUserId.matches($0.userId, myId) }
        }
        if DeviceUserId.matches(room.user1Id, myId) { return true }
        if let user2 = room.user2Id, DeviceUserId.matches(user2, myId) { return true }
        return false
    }

    /// 홈 카드 기본 방 이름 — 1:1은 상대 닉네임, 그룹은 다른 멤버 이름 나열.
    func defaultRoomTitle(for room: Room) -> String {
        let others = otherMemberDisplayNames(in: room)
        if others.isEmpty { return "채팅방" }
        if others.count == 1 { return others[0] }
        return others.prefix(3).joined(separator: ", ")
    }

    func defaultRoomEmoji(for room: Room) -> String {
        room.isMatched ? RoomCustomizationStore.defaultEmojiSymbol : "⏳"
    }

    /// 홈 카드·위젯 방 선택 — 로컬 커스텀 제목 우선, 없으면 `defaultRoomTitle`.
    func roomDisplayTitle(for room: Room) -> String {
        if let custom = RoomCustomizationStore.profile(for: room.id)?.title,
           !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return custom
        }
        return defaultRoomTitle(for: room)
    }

    /// 홈 카드 대표 이모지 — 사용자 설정 우선, 없으면 연결 상태 기본값.
    func roomDisplayEmoji(for room: Room) -> String {
        if let custom = RoomCustomizationStore.profile(for: room.id)?.emoji,
           !custom.isEmpty {
            return custom
        }
        return defaultRoomEmoji(for: room)
    }

    func customizationDraft(for room: Room) -> (title: String, emoji: String) {
        if let profile = RoomCustomizationStore.profile(for: room.id) {
            return (profile.title, profile.emoji)
        }
        return (defaultRoomTitle(for: room), defaultRoomEmoji(for: room))
    }

    func saveRoomCustomization(for room: Room, title: String, emoji: String) {
        let sanitizedTitle = RoomCustomizationStore.sanitizedTitle(title)
        let sanitizedEmoji = RoomCustomizationStore.primaryEmoji(from: emoji)
        if sanitizedTitle == defaultRoomTitle(for: room),
           sanitizedEmoji == defaultRoomEmoji(for: room) {
            RoomCustomizationStore.remove(for: room.id)
            return
        }
        RoomCustomizationStore.save(
            RoomCustomizationStore.Profile(title: sanitizedTitle, emoji: sanitizedEmoji),
            for: room.id
        )
        RoomPushTitleCache.syncDefaultDisplayTitle(defaultRoomTitle(for: room), for: room.id)
        AppGroupStorage.setPushRoomDisplayTitle(roomDisplayTitle(for: room), for: room.id)
    }

    /// UI·푸시용 상대 닉네임 (`DeviceUserId` 기준 — `==` 비교 금지).
    func partnerNickname(in room: Room) -> String {
        let others = otherMemberDisplayNames(in: room)
        if others.isEmpty { return "상대방" }
        if others.count == 1 { return others[0] }
        return others.joined(separator: ", ")
    }

    func myNickname(in room: Room) -> String? {
        let myId = currentUserId
        if let member = room.members.first(where: { DeviceUserId.matches($0.userId, myId) }) {
            let name = member.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        if DeviceUserId.matches(room.user1Id, myId), let name = room.user1Name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let user2 = room.user2Id, DeviceUserId.matches(user2, myId),
           let name = room.user2Name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return savedNickname
    }

    /// 시뮬레이터 재설치 등으로 `currentUserId`는 바뀌었지만 닉네임으로 같은 슬롯 재입장.
    private func alignLocalUserWithRoomIfNeeded(_ room: Room) async throws -> Room {
        try await alignMemberUserIdIfNeeded(room)
    }

    func syncSharedState(room: Room, nickname: String? = nil) {
        UserDefaults.standard.set(false, forKey: Constants.skipRoomAutoLoadKey)
        let nick = nickname ?? savedNickname
        AppGroupStorage.syncSession(roomId: room.id, userId: currentUserId, senderNickname: nick)
        if AppGroupStorage.widgetTargetRoomId == nil {
            AppGroupStorage.widgetTargetRoomId = room.id.uuidString
        }
        rememberRoomInCatalog(room)
        RoomPushTitleCache.syncDefaultDisplayTitle(defaultRoomTitle(for: room), for: room.id)
        AppGroupStorage.setPushRoomDisplayTitle(roomDisplayTitle(for: room), for: room.id)
        WidgetCenter.shared.reloadAllTimelines()
        Task { [weak self] in
            guard let self else { return }
            await self.ensureProfileRecordsForCurrentDevice()
            if let cachedToken = UserDefaults.standard.string(forKey: Constants.lastAPNSTokenKey), !cachedToken.isEmpty {
                _ = await self.updateAPNSToken(cachedToken)
            }
        }
    }

    /// 로컬 세션만 초기화 (Supabase 방 데이터는 유지). 자동 방 재진입을 막습니다.
    func clearLocalSession() {
        clearPersistedSession()
        AppGroupStorage.clearRoomSession()
        AppGroupStorage.syncUserId(currentUserId)
        UserDefaults.standard.set(true, forKey: Constants.skipRoomAutoLoadKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func prepareProfileDatabaseAccessForSafety() async -> Bool {
        await prepareProfileDatabaseAccessIfNeeded()
    }

    /// `room_members`에서 나가고 로컬 카탈로그에서 제거합니다.
    func leaveRoom(_ room: Room) async throws {
        _ = await prepareProfileDatabaseAccessIfNeeded()
        let myId = currentUserId
        if let member = room.members.first(where: { DeviceUserId.matches($0.userId, myId) }) {
            try await client
                .from(RoomMemberSchema.table)
                .delete()
                .eq("id", value: member.id)
                .execute()
        }
        removeRoomFromCatalog(id: room.id)
    }

    func otherMembersForSafety(in room: Room) -> [(userId: String, displayName: String)] {
        let myId = currentUserId
        if !room.members.isEmpty {
            return room.members
                .filter { !DeviceUserId.matches($0.userId, myId) }
                .map { ($0.userId, $0.displayName) }
        }
        var result: [(String, String)] = []
        if !DeviceUserId.matches(room.user1Id, myId) {
            let trimmed = room.user1Name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (trimmed?.isEmpty == false) ? trimmed! : partnerNickname(in: room)
            result.append((room.user1Id, name))
        }
        if let u2 = room.user2Id, !DeviceUserId.matches(u2, myId) {
            let trimmed = room.user2Name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (trimmed?.isEmpty == false) ? trimmed! : partnerNickname(in: room)
            result.append((u2, name))
        }
        return result
    }

    /// 서버 `delete_my_account_data` RPC 이후 로컬 데이터 전부 제거.
    func wipeAllLocalUserDataAfterServerDelete() {
        for id in knownRoomIds {
            removeRoomFromCatalog(id: id)
        }
        UserDefaults.standard.removeObject(forKey: Constants.knownRoomIdsKey)
        UserDefaults.standard.removeObject(forKey: Constants.lastRoomIdKey)
        UserDefaults.standard.removeObject(forKey: Constants.lastInviteCodeKey)
        UserSafetyStore.clearAll()
        clearLocalSession()
    }

    func persistSession(room: Room, nickname: String) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(room.id.uuidString, forKey: Constants.lastRoomIdKey)
        UserDefaults.standard.set(room.inviteCode, forKey: Constants.lastInviteCodeKey)
        saveNickname(trimmed)
        UserDefaults.standard.set(false, forKey: Constants.skipRoomAutoLoadKey)
        rememberRoomInCatalog(room)
    }

    func rememberRoomInCatalog(_ room: Room) {
        var ids = knownRoomIds
        ids.removeAll { $0 == room.id }
        ids.insert(room.id, at: 0)
        let capped = Array(ids.prefix(24))
        UserDefaults.standard.set(capped.map(\.uuidString), forKey: Constants.knownRoomIdsKey)
    }

    var knownRoomIds: [UUID] {
        guard let raw = UserDefaults.standard.stringArray(forKey: Constants.knownRoomIdsKey) else {
            return []
        }
        return raw.compactMap { UUID(uuidString: $0) }
    }

    func removeRoomFromCatalog(id: UUID) {
        RoomCustomizationStore.remove(for: id)
        let ids = knownRoomIds.filter { $0 != id }
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: Constants.knownRoomIdsKey)
        if lastPersistedRoomId == id {
            UserDefaults.standard.removeObject(forKey: Constants.lastRoomIdKey)
            UserDefaults.standard.removeObject(forKey: Constants.lastInviteCodeKey)
        }
        if AppGroupStorage.widgetTargetRoomId == id.uuidString {
            AppGroupStorage.widgetTargetRoomId = nil
        }
        if AppGroupStorage.currentRoomId == id.uuidString {
            AppGroupStorage.clearRoomSession()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 혼자만 있는 대기 방 — 방장 + 멤버 1명.
    func canDeleteWaitingRoom(_ room: Room) -> Bool {
        guard isRoomCreator(room) else { return false }
        return activeMemberCount(for: room) <= 1
    }

    /// DB에서 방·메시지 삭제 후 로컬 카탈로그에서 제거.
    func deleteWaitingRoom(id: UUID) async throws {
        let room = try await refreshRoom(id: id)
        guard canDeleteWaitingRoom(room) else {
            throw SupabaseManagerError.roomDeleteNotAllowed
        }

        try await client
            .from("messages")
            .delete()
            .eq("room_id", value: id)
            .execute()

        try await client
            .from("rooms")
            .delete()
            .eq("id", value: id)
            .execute()

        removeRoomFromCatalog(id: id)
    }

    /// 참여 중인 모든 방 (멤버십 + 로컬 카탈로그).
    func fetchJoinedRooms() async throws -> [Room] {
        UserDefaults.standard.set(false, forKey: Constants.skipRoomAutoLoadKey)
        var byId: [UUID: Room] = [:]

        for room in try await fetchAllRoomsByMembership() {
            var aligned = try await alignLocalUserWithRoomIfNeeded(room)
            aligned = try await hydrateRoom(aligned)
            byId[aligned.id] = aligned
            rememberRoomInCatalog(aligned)
        }

        for id in knownRoomIds {
            guard byId[id] == nil else { continue }
            if let room = try? await refreshRoom(id: id), isCurrentUserMember(of: room) {
                let aligned = try await alignLocalUserWithRoomIfNeeded(room)
                byId[aligned.id] = aligned
            }
        }

        let order = knownRoomIds + byId.keys.filter { !knownRoomIds.contains($0) }
        var seen = Set<UUID>()
        var sorted: [Room] = []
        for id in order {
            guard !seen.contains(id), let room = byId[id] else { continue }
            seen.insert(id)
            sorted.append(room)
        }
        for room in byId.values where !seen.contains(room.id) {
            sorted.append(room)
        }
        for room in sorted {
            RoomPushTitleCache.syncDefaultDisplayTitle(defaultRoomTitle(for: room), for: room.id)
            AppGroupStorage.setPushRoomDisplayTitle(roomDisplayTitle(for: room), for: room.id)
        }
        return sorted
    }

    private func fetchAllRoomsByMembership() async throws -> [Room] {
        var unique: [UUID: Room] = [:]

        for roomId in await fetchRoomIdsForCurrentUser() {
            if let room = try? await refreshRoom(id: roomId), isCurrentUserMember(of: room) {
                unique[room.id] = room
            }
        }

        for room in try await fetchLegacyRoomsByMembership() {
            try? await bootstrapMembershipIfNeeded(for: room)
            if let refreshed = try? await refreshRoom(id: room.id), isCurrentUserMember(of: refreshed) {
                unique[refreshed.id] = refreshed
            }
        }

        return Array(unique.values)
    }

    private func fetchLegacyRoomsByMembership() async throws -> [Room] {
        let userId = currentUserId
        var candidates: [Room] = []
        let idVariants = Array(Set([userId, userId.uppercased()]))

        for variant in idVariants {
            let filter = "user1_id.eq.\(variant),user2_id.eq.\(variant)"
            let chunk: [Room] = try await client
                .from("rooms")
                .select()
                .or(filter)
                .order("id", ascending: false)
                .limit(30)
                .execute()
                .value
            candidates.append(contentsOf: chunk)
        }

        var unique: [UUID: Room] = [:]
        for room in candidates where isCurrentUserMember(of: room) {
            unique[room.id] = room
        }
        return Array(unique.values)
    }

    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: Constants.lastRoomIdKey)
        UserDefaults.standard.removeObject(forKey: Constants.lastInviteCodeKey)
    }

    var lastPersistedRoomId: UUID? {
        guard let raw = UserDefaults.standard.string(forKey: Constants.lastRoomIdKey) else { return nil }
        return UUID(uuidString: raw)
    }

    func refreshWidgetTimelines() {
        syncUserIdToAppGroupIfNeeded()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func syncUserIdToAppGroupIfNeeded() {
        AppGroupStorage.syncUserId(currentUserId)
    }

    func createRoom(nickname: String) async throws -> Room {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔥 [CreateRoom] nickname(raw)=\(nickname) trimmed=\(trimmedNickname)")

        guard Self.isValidNickname(trimmedNickname) else {
            print("❌ [CreateRoom 에러 발생]: invalidNickname")
            throw SupabaseManagerError.invalidNickname
        }

        saveNickname(trimmedNickname)

        let inviteCode = Self.makeInviteCode()
        let userId = currentUserId
        let payload = NewRoomPayload(
            inviteCode: inviteCode,
            user1Id: userId,
            user1Name: trimmedNickname
        )

        print(
            """
            🔥 [CreateRoom] INSERT payload \
            invite_code=\(inviteCode) user1_id=\(userId) user1_name=\(trimmedNickname)
            """
        )

        let room: Room = try await client
            .from("rooms")
            .insert(payload, returning: .representation)
            .single()
            .execute()
            .value

        print("✅ [CreateRoom] INSERT 성공 room_id=\(room.id.uuidString)")
        try await addCreatorMember(room: room, nickname: trimmedNickname)
        let hydrated = try await refreshRoom(id: room.id)
        syncSharedState(room: hydrated, nickname: trimmedNickname)
        persistSession(room: hydrated, nickname: trimmedNickname)
        return hydrated
    }

    func joinRoom(code rawCode: String, nickname: String) async throws -> Room {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidNickname(trimmedNickname) else {
            throw SupabaseManagerError.invalidNickname
        }

        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard InviteCodeValidator.isValidLength(code) else {
            throw SupabaseManagerError.invalidInviteCode
        }

        saveNickname(trimmedNickname)

        let roomMatches: [Room] = try await client
            .from("rooms")
            .select()
            .eq("invite_code", value: code)
            .limit(1)
            .execute()
            .value
        guard let existing = roomMatches.first else {
            throw SupabaseManagerError.roomNotFound
        }

        try await bootstrapMembershipIfNeeded(for: existing)
        var room = try await refreshRoom(id: existing.id)

        if isCurrentUserMember(of: room) {
            try await updateMyMemberDisplayName(in: room, nickname: trimmedNickname)
            return try await finalizeMembershipMutation(roomId: room.id, nickname: trimmedNickname)
        }

        if let byName = room.members.first(where: { $0.displayName == trimmedNickname }) {
            try await updateMemberUserId(memberId: byName.id, userId: currentUserId)
            try await updateMyMemberDisplayName(in: room, nickname: trimmedNickname)
            return try await finalizeMembershipMutation(roomId: room.id, nickname: trimmedNickname)
        }

        let joined = try await joinRoomMembers(existing: existing, nickname: trimmedNickname)
        return try await finalizeMembershipMutation(roomId: joined.id, nickname: trimmedNickname)
    }

    private func finalizeMembershipMutation(roomId: UUID, nickname: String) async throws -> Room {
        let refreshed = try await refreshRoom(id: roomId)
        syncSharedState(room: refreshed, nickname: nickname)
        persistSession(room: refreshed, nickname: nickname)
        return refreshed
    }

    func rejoinAsUser1(existing: Room) async throws -> Room {
        guard !DeviceUserId.matches(existing.user1Id, currentUserId) else { return existing }

        return try await client
            .from("rooms")
            .update(RejoinUser1Payload(user1Id: currentUserId), returning: .representation)
            .eq("id", value: existing.id)
            .single()
            .execute()
            .value
    }

    func rejoinAsUser2(existing: Room) async throws -> Room {
        guard !(existing.user2Id.map { DeviceUserId.matches($0, currentUserId) } ?? false) else { return existing }

        return try await client
            .from("rooms")
            .update(RejoinUser2Payload(user2Id: currentUserId), returning: .representation)
            .eq("id", value: existing.id)
            .single()
            .execute()
            .value
    }

    var savedNickname: String? {
        UserDefaults.standard.string(forKey: Constants.nicknameDefaultsKey)
    }

    private func saveNickname(_ nickname: String) {
        UserDefaults.standard.set(nickname, forKey: Constants.nicknameDefaultsKey)
    }

    private static func isValidNickname(_ nickname: String) -> Bool {
        NicknameValidator.isValid(nickname)
    }

    func fetchCurrentRoom() async throws -> Room? {
        if UserDefaults.standard.bool(forKey: Constants.skipRoomAutoLoadKey) {
            return nil
        }

        var resolved: Room?

        if let lastId = lastPersistedRoomId {
            do {
                resolved = try await refreshRoom(id: lastId)
                print("✅ [Session] lastRoomId로 refresh room=\(lastId)")
            } catch {
                print("⚠️ [Session] lastRoomId refresh 실패 — invite/membership 폴백")
                clearPersistedSession()
            }
        }

        if resolved == nil, let code = UserDefaults.standard.string(forKey: Constants.lastInviteCodeKey),
           !code.isEmpty {
            let matches: [Room] = try await client
                .from("rooms")
                .select()
                .eq("invite_code", value: code)
                .limit(1)
                .execute()
                .value
            resolved = matches.first
            if resolved != nil {
                print("✅ [Session] invite_code로 room 복구 code=\(code.prefix(4))…")
            }
        }

        if resolved == nil {
            resolved = try await fetchRoomByMembership()
        }

        guard var room = resolved else {
            return nil
        }

        room = try await alignLocalUserWithRoomIfNeeded(room)
        syncSharedState(room: room, nickname: savedNickname)
        if let nickname = savedNickname {
            persistSession(room: room, nickname: nickname)
        }
        print(
            """
            ✅ [Session] room ready id=\(room.id.uuidString.prefix(8))… \
            member=\(isCurrentUserMember(of: room)) partner=\(partnerNickname(in: room))
            """
        )
        return room
    }

    /// 앱 포그라운드·채팅 진입 시 최신 `rooms` 행으로 UI 갱신.
    func refreshPersistedRoomIfNeeded() async -> Room? {
        guard let roomId = lastPersistedRoomId else { return nil }
        do {
            var room = try await refreshRoom(id: roomId)
            room = try await alignLocalUserWithRoomIfNeeded(room)
            syncSharedState(room: room, nickname: savedNickname)
            if let nickname = savedNickname {
                persistSession(room: room, nickname: nickname)
            }
            return room
        } catch {
            print("⚠️ [Session] refreshPersistedRoom 실패: \(error)")
            return nil
        }
    }

    private func fetchRoomByMembership() async throws -> Room? {
        let userId = currentUserId
        var candidates: [Room] = []
        let idVariants = Array(Set([userId, userId.uppercased()]))

        for variant in idVariants {
            let filter = "user1_id.eq.\(variant),user2_id.eq.\(variant)"
            let chunk: [Room] = try await client
                .from("rooms")
                .select()
                .or(filter)
                .limit(3)
                .execute()
                .value
            candidates.append(contentsOf: chunk)
        }

        if let matched = candidates.first(where: { isCurrentUserMember(of: $0) }) {
            return matched
        }
        return nil
    }

    /// 앱 UI에서 넛지 파이프라인을 검증할 때 사용 (위젯과 동일 로직).
    func sendTestNudge() async -> NudgeSendResult {
        await NudgeService.sendNudgeIfAllowed()
    }

    func refreshRoom(id: UUID) async throws -> Room {
        let room: Room = try await client
            .from("rooms")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return try await hydrateRoom(room)
    }

    /// Realtime으로 방·멤버 변경 감지 (폴링 루프 없음 — 과부하 방지).
    func watchRoomUpdates(roomId: UUID) -> AsyncStream<Room> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                defer { continuation.finish() }

                let tracker = RoomWatchRevisionTracker()

                if let initial = try? await self.refreshRoom(id: roomId) {
                    if tracker.shouldEmit(revision: self.roomMembershipRevision(for: initial)) {
                        continuation.yield(initial)
                    }
                }

                let channel = self.client.channel("room-watch-\(roomId.uuidString)")
                let roomUpdates = channel.postgresChange(
                    UpdateAction.self,
                    schema: "public",
                    table: "rooms",
                    filter: .eq("id", value: roomId)
                )
                let memberChanges = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "room_members",
                    filter: .eq("room_id", value: roomId)
                )
                let memberUpdates = channel.postgresChange(
                    UpdateAction.self,
                    schema: "public",
                    table: "room_members",
                    filter: .eq("room_id", value: roomId)
                )
                let memberDeletes = channel.postgresChange(
                    DeleteAction.self,
                    schema: "public",
                    table: "room_members",
                    filter: .eq("room_id", value: roomId)
                )

                var realtimeReady = false
                if (try? await channel.subscribeWithError()) != nil {
                    realtimeReady = true
                }

                if realtimeReady {
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask { [weak self] in
                            for await _ in roomUpdates {
                                guard !Task.isCancelled, let self else { break }
                                await self.emitRoomIfChanged(roomId: roomId, tracker: tracker, continuation: continuation)
                            }
                        }
                        group.addTask { [weak self] in
                            for await _ in memberChanges {
                                guard !Task.isCancelled, let self else { break }
                                await self.emitRoomIfChanged(roomId: roomId, tracker: tracker, continuation: continuation)
                            }
                        }
                        group.addTask { [weak self] in
                            for await _ in memberUpdates {
                                guard !Task.isCancelled, let self else { break }
                                await self.emitRoomIfChanged(roomId: roomId, tracker: tracker, continuation: continuation)
                            }
                        }
                        group.addTask { [weak self] in
                            for await _ in memberDeletes {
                                guard !Task.isCancelled, let self else { break }
                                await self.emitRoomIfChanged(roomId: roomId, tracker: tracker, continuation: continuation)
                            }
                        }
                    }
                } else {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: Constants.matchPollInterval)
                        guard !Task.isCancelled else { break }
                        await self.emitRoomIfChanged(roomId: roomId, tracker: tracker, continuation: continuation)
                    }
                }

                if realtimeReady {
                    await self.client.removeChannel(channel)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func roomMembershipRevision(for room: Room) -> String {
        let memberPart = room.members
            .map { "\($0.userId.lowercased()):\($0.displayName)" }
            .sorted()
            .joined(separator: "|")
        return "\(room.id.uuidString)#\(memberPart)"
    }

    private func emitRoomIfChanged(
        roomId: UUID,
        tracker: RoomWatchRevisionTracker,
        continuation: AsyncStream<Room>.Continuation
    ) async {
        guard let room = try? await self.refreshRoom(id: roomId) else { return }
        let revision = self.roomMembershipRevision(for: room)
        guard tracker.shouldEmit(revision: revision) else { return }
        continuation.yield(room)
    }
}

private final class RoomWatchRevisionTracker: @unchecked Sendable {
    private var lock = NSLock()
    private var lastRevision: String?

    func shouldEmit(revision: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard lastRevision != revision else { return false }
        lastRevision = revision
        return true
    }
}

extension SupabaseManager {
    func uploadMedia(
        data: Data,
        fileExtension: String,
        contentType: String
    ) async throws -> String {
        let path = "\(currentUserId)/\(UUID().uuidString).\(fileExtension)"
        return try await uploadMedia(data: data, storagePath: path, contentType: contentType)
    }

    func uploadMedia(
        data: Data,
        storagePath: String,
        contentType: String
    ) async throws -> String {
        guard !data.isEmpty else {
            throw SupabaseManagerError.emptyMediaData
        }

        let options = FileOptions(contentType: contentType, upsert: false)

        try await client.storage
            .from(Constants.mediaBucket)
            .upload(storagePath, data: data, options: options)

        let publicURL = try client.storage
            .from(Constants.mediaBucket)
            .getPublicURL(path: storagePath)

        let urlString = publicURL.absoluteString
        print("✅ [Storage] upload bucket=\(Constants.mediaBucket) path=\(storagePath)")
        print("✅ [Storage] public URL=\(MediaURLResolver.sanitizedRaw(urlString) ?? urlString)")

        return MediaURLResolver.sanitizedRaw(urlString) ?? urlString
    }

    func uploadDrawingMedia(roomId: UUID, jpegData: Data) async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let path = "\(roomId.uuidString)/drawings/\(fileName)"
        return try await uploadMedia(
            data: jpegData,
            storagePath: path,
            contentType: "image/jpeg"
        )
    }

    func uploadPhotoMedia(roomId: UUID, jpegData: Data) async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let path = "\(roomId.uuidString)/photos/\(fileName)"
        return try await uploadMedia(
            data: jpegData,
            storagePath: path,
            contentType: "image/jpeg"
        )
    }

    /// DB에 상대 경로만 저장된 경우 공개 URL로 변환합니다.
    func resolvePublicMediaURL(_ mediaUrl: String?) -> URL? {
        guard let cleaned = MediaURLResolver.sanitizedRaw(mediaUrl) else { return nil }

        if cleaned.hasPrefix("http://") || cleaned.hasPrefix("https://") {
            return MediaURLResolver.urlFromHTTPString(cleaned)
        }

        do {
            let publicURL = try client.storage.from(Constants.mediaBucket).getPublicURL(path: cleaned)
            return MediaURLResolver.urlFromHTTPString(publicURL.absoluteString)
        } catch {
            print("⚠️ [Storage] getPublicURL 실패 path=\(cleaned) error=\(error)")
            return MediaURLResolver.urlFromHTTPString(cleaned)
        }
    }

    func uploadMedia(data: Data, isVideo: Bool) async throws -> String {
        let fileExtension = isVideo ? "mp4" : "jpg"
        let contentType = isVideo ? "video/mp4" : "image/jpeg"
        return try await uploadMedia(data: data, fileExtension: fileExtension, contentType: contentType)
    }

    func insertMessage(
        roomId: UUID,
        type: String,
        senderNickname: String,
        content: String?,
        mediaURL: String?
    ) async throws {
        let payload = MediaMessageInsert(
            roomId: roomId,
            type: type,
            senderId: currentUserId,
            senderNickname: senderNickname,
            mediaUrl: mediaURL,
            content: content
        )

        try await client
            .from("messages")
            .insert(payload)
            .execute()
    }

    func sendEmojiMessage(roomId: UUID, senderNickname: String, content: String) async throws -> MediaMessage {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SupabaseManagerError.emptyMediaData
        }

        let payload = MediaMessageInsert(
            roomId: roomId,
            type: "emoji",
            senderId: currentUserId,
            senderNickname: senderNickname,
            mediaUrl: nil,
            content: trimmed
        )

        let message: MediaMessage = try await client
            .from("messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        await notifyPartnerPush(for: message)
        return message
    }

    func sendKeycapNudge(roomId: UUID, senderNickname: String, symbolKey: String) async throws -> MediaMessage {
        guard AppGroupStorage.isActiveKeycapType(symbolKey) else {
            throw SupabaseManagerError.emptyMediaData
        }
        let text = AppGroupStorage.getMessage(for: symbolKey)
        let content = text

        let payload = MediaMessageInsert(
            roomId: roomId,
            type: "nudge",
            senderId: currentUserId,
            senderNickname: senderNickname,
            mediaUrl: nil,
            content: content
        )

        let message: MediaMessage = try await client
            .from("messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        await notifyPartnerPush(for: message)
        return message
    }

    func sendEmergencyNudge(roomId: UUID, senderNickname: String) async throws -> MediaMessage {
        let content = AppGroupStorage.emergencyDisplayText

        let payload = MediaMessageInsert(
            roomId: roomId,
            type: AppGroupStorage.emergencyNudgeType,
            senderId: currentUserId,
            senderNickname: senderNickname,
            mediaUrl: nil,
            content: content
        )

        let message: MediaMessage = try await client
            .from("messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        AppGroupStorage.lastEmergencySentAt = Date()
        await notifyPartnerPush(for: message)
        return message
    }

    /// `messages` INSERT Realtime — 방의 모든 메시지 타입(넛지 포함)을 방출합니다.
    func watchChatMessageInserts(roomId: UUID) -> AsyncStream<MediaMessage> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                defer { continuation.finish() }

                let channel = self.client.channel("room-messages-\(roomId.uuidString)")
                let inserts = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "messages",
                    filter: .eq("room_id", value: roomId)
                )

                var subscribed = false
                if (try? await channel.subscribeWithError()) != nil {
                    subscribed = true
                } else {
                    print("⚠️ [Realtime] messages 채널 구독 실패 — room \(roomId)")
                }

                guard subscribed else { return }

                for await insert in inserts {
                    guard !Task.isCancelled else { break }
                    guard let message = try? insert.decodeRecord(as: MediaMessage.self, decoder: Self.jsonDecoder) else {
                        continue
                    }
                    continuation.yield(message)
                }

                await self.client.removeChannel(channel)
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// `messages` UPDATE Realtime — 읽음(`is_read`) 등 변경 시 방출합니다.
    func watchChatMessageUpdates(roomId: UUID) -> AsyncStream<MediaMessage> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                defer { continuation.finish() }

                let channel = self.client.channel("room-messages-updates-\(roomId.uuidString)")
                let updates = channel.postgresChange(
                    UpdateAction.self,
                    schema: "public",
                    table: "messages",
                    filter: .eq("room_id", value: roomId)
                )

                var subscribed = false
                if (try? await channel.subscribeWithError()) != nil {
                    subscribed = true
                } else {
                    print("⚠️ [Realtime] messages UPDATE 채널 구독 실패 — room \(roomId)")
                }

                guard subscribed else { return }

                for await update in updates {
                    guard !Task.isCancelled else { break }
                    guard let message = try? update.decodeRecord(as: MediaMessage.self, decoder: Self.jsonDecoder) else {
                        continue
                    }
                    guard Self.isChatVisibleMessage(message) else { continue }
                    continuation.yield(message)
                }

                await self.client.removeChannel(channel)
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 상대방이 보낸 미읽음 메시지를 읽음 처리합니다 (채팅방 진입·포그라운드·상대 메시지 수신 시).
    func markMessagesAsRead(roomId: UUID) async {
        do {
            try await client
                .from("messages")
                .update(MessageReadPatch())
                .eq("room_id", value: roomId)
                .eq("is_read", value: false)
                .neq("sender_id", value: currentUserId)
                .execute()
        } catch {
            print("⚠️ [Read] markMessagesAsRead 실패: \(error)")
            print(
                """
                ⚠️ `messages.is_read` 컬럼이 없을 수 있습니다. Supabase SQL Editor에서 실행:
                ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;
                """
            )
        }
    }

    /// @deprecated 호환 — `watchChatMessageInserts` 사용
    func watchEmojiMessageInserts(roomId: UUID) -> AsyncStream<MediaMessage> {
        watchChatMessageInserts(roomId: roomId)
    }

    static func isChatVisibleMessage(_ message: MediaMessage) -> Bool {
        Constants.chatMessageTypes.contains(message.type)
    }

    /// 메인 채팅방: 기기 로컬 타임존 기준 오늘 00:00 (Calendar.current).
    static func startOfChatToday(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: Date())
    }

    static func chatTodayStartISO8601(calendar: Calendar = .current) -> String {
        iso8601String(for: startOfChatToday(calendar: calendar))
    }

    static func isCreatedOnChatToday(_ createdAt: Date, calendar: Calendar = .current) -> Bool {
        createdAt >= startOfChatToday(calendar: calendar)
    }

    static func chatDayToken(calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: startOfChatToday(calendar: calendar))
    }

    private static func iso8601String(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: string) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(string)")
        }
        return decoder
    }()

    func sendPhotoMessage(roomId: UUID, senderNickname: String, jpegData: Data) async throws -> MediaMessage {
        let compressed = PhotoMediaPipeline.jpegData(from: jpegData) ?? jpegData
        let url = try await uploadPhotoMedia(roomId: roomId, jpegData: compressed)

        let payload = MediaMessageInsert(
            roomId: roomId,
            type: "photo",
            senderId: currentUserId,
            senderNickname: senderNickname,
            mediaUrl: url,
            content: nil
        )

        let message: MediaMessage = try await client
            .from("messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        print("✅ [Messages] photo insert media_url=\(message.mediaUrl ?? "nil")")
        await notifyPartnerPush(for: message)
        return message
    }

    func sendDrawingMessage(roomId: UUID, senderNickname: String, jpegData: Data) async throws -> MediaMessage {
        let compressed = PhotoMediaPipeline.jpegData(from: jpegData) ?? jpegData
        let url = try await uploadDrawingMedia(roomId: roomId, jpegData: compressed)

        let payload = MediaMessageInsert(
            roomId: roomId,
            type: "drawing",
            senderId: currentUserId,
            senderNickname: senderNickname,
            mediaUrl: url,
            content: nil
        )

        let message: MediaMessage = try await client
            .from("messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        print("✅ [Messages] drawing insert media_url=\(message.mediaUrl ?? "nil")")
        await notifyPartnerPush(for: message)
        return message
    }

    func sendMediaMessage(roomId: UUID, mediaURL: String) async throws {
        let nickname = savedNickname ?? "unknown"
        try await insertMessage(
            roomId: roomId,
            type: "media",
            senderNickname: nickname,
            content: nil,
            mediaURL: mediaURL
        )
    }

    func uploadAndSendMedia(roomId: UUID, data: Data, isVideo: Bool) async throws -> String {
        let mediaURL = try await uploadMedia(data: data, isVideo: isVideo)
        try await sendMediaMessage(roomId: roomId, mediaURL: mediaURL)
        return mediaURL
    }

    /// 캘린더 아카이브용 — 해당 월(로컬 타임존) 전체 메시지(넛지 포함).
    func fetchMessagesForMonth(roomId: UUID, month: Date) async throws -> [MediaMessage] {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        guard let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return []
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)

        return try await client
            .from("messages")
            .select()
            .eq("room_id", value: roomId)
            .gte("created_at", value: startString)
            .lt("created_at", value: endString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func fetchChatMessages(roomId: UUID) async throws -> [MediaMessage] {
        let todayStartISO = Self.chatTodayStartISO8601()
        let all: [MediaMessage] = try await client
            .from("messages")
            .select()
            .eq("room_id", value: roomId)
            .gte("created_at", value: todayStartISO)
            .order("created_at", ascending: true)
            .execute()
            .value

        return all.filter { Self.isChatVisibleMessage($0) }
    }

    func fetchEmojiMessages(roomId: UUID) async throws -> [MediaMessage] {
        try await client
            .from("messages")
            .select()
            .eq("room_id", value: roomId)
            .eq("type", value: "emoji")
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func fetchMessages(roomId: UUID) async throws -> [MediaMessage] {
        try await client
            .from("messages")
            .select()
            .eq("room_id", value: roomId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Anonymous Auth 세션이 **완료된 뒤에만** true. Probe·토큰 저장 전에 반드시 await.
    @discardableResult
    func ensureAuthenticatedSessionForProfiles() async -> Bool {
        let ready = await prepareProfileDatabaseAccessIfNeeded()
        if ready {
            logInsertIdVsAuthVerification(profileInsertId: currentUserId)
        }
        return ready
    }

    /// INSERT `profiles.id` ↔ `auth.currentUser.id` / RLS WITH CHECK 경로 검증 로그.
    private func logInsertIdVsAuthVerification(profileInsertId: String) {
        guard let user = client.auth.currentUser else {
            print("🔴 [Auth↔Profile] auth.currentUser == nil — signInAnonymously 완료 전 DB write 금지")
            return
        }

        let authUID = DeviceUserId.canonical(user.id.uuidString)
        let insertId = profileInsertId
        let insertCanonical = DeviceUserId.canonical(profileInsertId)
        let metaDevice = user.userMetadata["device_user_id"]?.stringValue ?? ""

        let matchesAuthUID = insertCanonical == authUID
        let matchesMetadata = DeviceUserId.matches(metaDevice, insertId)
        let rlsWouldPass = matchesMetadata || matchesAuthUID

        print(
            """
            🔍 [Auth↔Profile] RLS 사전 검증
            profiles INSERT id=\"\(insertId)\"
            auth.currentUser.id=\"\(authUID)\"
            insertId == auth.uid? \(matchesAuthUID) (SignalApp: 보통 false — Edge는 rooms device id 조회)
            JWT user_metadata.device_user_id=\"\(metaDevice)\"
            insertId ↔ metadata (RLS primary)? \(matchesMetadata)
            profile_id_owned_by_caller 예상? \(rlsWouldPass)
            """
        )

        if !rlsWouldPass {
            print("🔴 [Auth↔Profile] WITH CHECK 실패 예상 — refreshSession·metadata 동기화 후 재시도 필요")
        }
    }

    /// Supabase Auth(익명) + JWT `user_metadata.device_user_id` = `currentUserId` (RLS 필수).
    @discardableResult
    private func prepareProfileDatabaseAccessIfNeeded() async -> Bool {
        let deviceId = currentUserId

        for attempt in 1 ... 3 {
            do {
                if client.auth.currentSession == nil {
                    let session = try await client.auth.signInAnonymously(
                        data: ["device_user_id": AnyJSON.string(deviceId)]
                    )
                    _ = try await client.auth.refreshSession()
                    print("✅ [APNs] signInAnonymously 완료 user=\(session.user.id.uuidString.prefix(8))… (attempt \(attempt))")
                    try await Task.sleep(for: .milliseconds(150))
                }

                let meta = client.auth.currentSession?.user.userMetadata["device_user_id"]?.stringValue
                if !DeviceUserId.matches(meta ?? "", deviceId) {
                    try await client.auth.update(
                        user: UserAttributes(data: ["device_user_id": AnyJSON.string(deviceId)])
                    )
                    _ = try await client.auth.refreshSession()
                    try await Task.sleep(for: .milliseconds(150))
                    print("✅ [APNs] metadata device_user_id 갱신 + refreshSession 완료")
                }

                guard let session = client.auth.currentSession,
                      !session.accessToken.isEmpty,
                      client.auth.currentUser != nil else {
                    print("🔴 [APNs] 세션 없음 또는 accessToken 비어 있음 (attempt \(attempt))")
                    continue
                }

                let verified = session.user.userMetadata["device_user_id"]?.stringValue
                if DeviceUserId.matches(verified ?? "", deviceId) {
                    logAuthJWTProfileBinding()
                    print("🔐 [APNs] auth role=\(session.user.role ?? "?") sessionReady=true")
                    return true
                }

                print("🔴 [APNs] metadata MISMATCH meta=\(verified ?? "nil") device=\(deviceId) (attempt \(attempt))")
            } catch {
                SupabaseProfileWriteProbe.logError(context: "prepareProfileDatabaseAccess attempt \(attempt)", error: error)
                if attempt == 3 {
                    print("🔴 [APNs] Anonymous sign-in 비활성화 가능 — Supabase Dashboard → Authentication → Providers")
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
        return false
    }

    private func logProfileIdentityContext(phase: String) {
        let profileId = currentUserId
        let session = client.auth.currentSession
        let authUserId = session?.user.id.uuidString
        let metaDeviceId = session?.user.userMetadata["device_user_id"]?.stringValue

        print(
            """
            🔑 [APNs] \(phase)
            profiles.id(upsert)=\(profileId)
            auth.uid(Supabase Auth)=\(authUserId ?? "nil")
            metadata.device_user_id=\(metaDeviceId ?? "nil")
            profileId↔metadata=\(metaDeviceId.map { DeviceUserId.matches($0, profileId) } == true ? "MATCH" : "MISMATCH")
            ℹ️ 푸시 조회 키는 auth.uid가 아니라 rooms의 user1_id/user2_id = profiles.id
            """
        )
    }

    private func logAuthJWTProfileBinding() {
        let meta = client.auth.currentSession?.user.userMetadata["device_user_id"]?.stringValue
        print("🔐 [APNs] JWT user_metadata.device_user_id=\(meta ?? "nil") (RLS: lower(profiles.id) = lower(metadata))")
    }

    /// `assumeAuthReady`: true면 `ensureAuthenticatedSessionForProfiles()` 직후 호출 (중복 sign-in 방지).
    @discardableResult
    func runProfilesDatabaseWriteProbe(assumeAuthReady: Bool = false) async -> Bool {
        print("🧪 [Profiles Probe] === DB write test start assumeAuthReady=\(assumeAuthReady) ===")

        if assumeAuthReady {
            guard client.auth.currentSession != nil, client.auth.currentUser != nil else {
                print("🧪 [Profiles Probe] FAIL — assumeAuthReady but session nil")
                return false
            }
        } else {
            guard await ensureAuthenticatedSessionForProfiles() else {
                print("🧪 [Profiles Probe] FAIL — auth/session")
                return false
            }
        }

        let probeId = currentUserId
        logInsertIdVsAuthVerification(profileInsertId: probeId)

        if let row = await insertProfileRowWithRepresentation(profileId: probeId, apnsToken: nil, context: "Profiles Probe") {
            print("🧪 [Profiles Probe] SUCCESS INSERT return=representation id=\"\(row.id)\" apns_token=\(row.apnsToken ?? "null")")
            return true
        }

        print("🧪 [Profiles Probe] FAIL — INSERT returned no row (see 🔴/🟠 logs above)")
        return false
    }

    /// `return=representation` — HTTP 2xx + 빈 배열이면 RLS silent block으로 로깅.
    private func insertProfileRowWithRepresentation(profileId: String, apnsToken: String?, context: String) async -> UserProfile? {
        logInsertIdVsAuthVerification(profileInsertId: profileId)
        let payload = ProfileRowInsert(id: profileId, apnsToken: apnsToken)
        do {
            let rows: [UserProfile] = try await client
                .from("profiles")
                .insert(payload, returning: .representation)
                .select("id,apns_token")
                .execute()
                .value
            if let row = rows.first {
                SupabaseProfileWriteProbe.logSuccess(context: "\(context) INSERT", profileId: row.id)
                return row
            }
            SupabaseProfileWriteProbe.logSilentRLSBlock(context: "\(context) INSERT", profileId: profileId)
            return nil
        } catch {
            SupabaseProfileWriteProbe.logError(context: "\(context) INSERT id=\(profileId)", error: error)
            return nil
        }
    }

    private func upsertProfileAPNSWithRepresentation(profileId: String, token: String, context: String) async -> UserProfile? {
        let payload = ProfileAPNSUpsert(id: profileId, apnsToken: token)
        do {
            let rows: [UserProfile] = try await client
                .from("profiles")
                .upsert(payload, onConflict: "id", returning: .representation)
                .select("id,apns_token")
                .execute()
                .value
            if let row = rows.first {
                SupabaseProfileWriteProbe.logSuccess(
                    context: "\(context) UPSERT",
                    profileId: row.id,
                    extra: "tokenLen=\(row.apnsToken?.count ?? 0)"
                )
                return row
            }
            SupabaseProfileWriteProbe.logSilentRLSBlock(context: "\(context) UPSERT", profileId: profileId)
            return nil
        } catch {
            SupabaseProfileWriteProbe.logError(context: "\(context) UPSERT id=\(profileId)", error: error)
            return nil
        }
    }

    private func upsertProfileRowWithRepresentation(profileId: String, apnsToken: String?, context: String) async -> UserProfile? {
        let payload = ProfileRowInsert(id: profileId, apnsToken: apnsToken)
        do {
            let rows: [UserProfile] = try await client
                .from("profiles")
                .upsert(payload, onConflict: "id", returning: .representation)
                .select("id,apns_token")
                .execute()
                .value
            if let row = rows.first {
                SupabaseProfileWriteProbe.logSuccess(context: "\(context) UPSERT row", profileId: row.id)
                return row
            }
            SupabaseProfileWriteProbe.logSilentRLSBlock(context: "\(context) UPSERT row", profileId: profileId)
            return nil
        } catch {
            SupabaseProfileWriteProbe.logError(context: "\(context) UPSERT row id=\(profileId)", error: error)
            return nil
        }
    }

    /// 앱 실행 시 `profiles` 행이 없으면 생성 (apns_token은 이후 didRegister에서 채움).
    func ensureProfileRecordsForCurrentDevice() async {
        logProfileIdentityContext(phase: "ensureProfileRecords")
        guard await ensureAuthenticatedSessionForProfiles() else {
            print("🔴 [APNs] FAILURE ensureProfileRecords — auth 준비 실패")
            _ = await runProfilesDatabaseWriteProbe(assumeAuthReady: false)
            return
        }

        let profileIds = await resolvedProfileIdsForPushStorage()
        print("🔑 [APNs] ensureProfileRecords targets: \(profileIds.joined(separator: " | "))")

        var createdAny = false
        for profileId in profileIds {
            if await ensureProfileRowExists(profileId: profileId) {
                createdAny = true
            }
        }

        if createdAny {
            print("🟢 [APNs] SUCCESS ensureProfileRecords — profiles 행 준비됨 primary=\(currentUserId)")
        } else {
            print("🔴 [APNs] FAILURE ensureProfileRecords — Probe 재실행")
            _ = await runProfilesDatabaseWriteProbe(assumeAuthReady: true)
        }
    }

    private func fetchProfileRow(profileId: String) async -> UserProfile? {
        let lookupIds = Array(Set([profileId, DeviceUserId.canonical(profileId)]))
        for lookupId in lookupIds {
            do {
                let rows: [UserProfile] = try await client
                    .from("profiles")
                    .select("id,apns_token")
                    .eq("id", value: lookupId)
                    .limit(1)
                    .execute()
                    .value
                if let row = rows.first {
                    return row
                }
            } catch {
                SupabaseProfileWriteProbe.logError(context: "fetchProfileRow id=\(lookupId)", error: error)
            }
        }
        return nil
    }

    /// `profiles` 행이 없으면 `apns_token` null 로 INSERT. 있으면 🟢 로그만.
    @discardableResult
    private func ensureProfileRowExists(profileId: String) async -> Bool {
        if let existing = await fetchProfileRow(profileId: profileId) {
            let hasToken = !(existing.apnsToken?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            print("🟢 [APNs] SUCCESS profile row exists id=\(existing.id) apns_token=\(hasToken ? "set" : "empty")")
            return true
        }

        print("📝 [APNs] profiles 행 없음 — INSERT 시도 id=\(profileId)")

        if await insertProfileRowWithRepresentation(profileId: profileId, apnsToken: nil, context: "ensureProfileRow") != nil {
            return true
        }

        if await upsertProfileRowWithRepresentation(profileId: profileId, apnsToken: nil, context: "ensureProfileRow") != nil {
            return true
        }

        if await confirmProfileRowExists(profileId: profileId) {
            print("🟢 [APNs] SUCCESS profile row read-back id=\(profileId)")
            return true
        }

        print("🔴 [APNs] FAILURE ensureProfileRow — INSERT/UPSERT representation empty + SELECT miss id=\(profileId)")
        return false
    }

    private func confirmProfileRowExists(profileId: String) async -> Bool {
        await fetchProfileRow(profileId: profileId) != nil
    }

    /// 방 `rooms`에 등록된 내 id(대소문자 포함)와 canonical id 모두에 토큰을 저장 — Edge `recipient_id`와 일치.
    private func resolvedProfileIdsForPushStorage() async -> [String] {
        let primary = currentUserId
        var idSet = Set<String>()
        idSet.insert(primary)
        idSet.insert(DeviceUserId.canonical(primary))

        var edgeKeyFirst: String?

        if let roomId = lastPersistedRoomId, let room = try? await refreshRoom(id: roomId) {
            let partner = partnerUserId(in: room)
            edgeKeyFirst = edgeRecipientIdForThisDevice(in: room)
            let inRoom = isCurrentUserMember(of: room)

            if let edgeKeyFirst {
                idSet.insert(edgeKeyFirst)
                idSet.insert(DeviceUserId.canonical(edgeKeyFirst))
            }

            for member in room.members where DeviceUserId.matches(member.userId, primary) {
                idSet.insert(member.userId)
                idSet.insert(DeviceUserId.canonical(member.userId))
            }

            for raw in [room.user1Id, room.user2Id ?? ""] where !raw.isEmpty {
                if DeviceUserId.matches(raw, primary) {
                    idSet.insert(raw)
                    idSet.insert(DeviceUserId.canonical(raw))
                }
            }

            print(
                """
                🧭 [APNs] room-alignment room_id=\(room.id.uuidString)
                Edge recipient_id (나)=\(edgeKeyFirst ?? "MISMATCH")
                partner recipient_id (첫 상대)=\(partner ?? "nil")
                inRoom=\(inRoom)
                """
            )

            if !inRoom {
                print("🔴 [APNs] WARNING — myId가 room 멤버와 불일치. 재입장 시 user id 갱신 필요")
            }
        } else {
            print("🧭 [APNs] room-alignment — 저장된 방 없음 (profiles.id=\(primary) 만 upsert)")
        }

        var ordered: [String] = []
        if let edgeKeyFirst, !edgeKeyFirst.isEmpty {
            ordered.append(edgeKeyFirst)
        }
        for id in idSet where !ordered.contains(id) {
            ordered.append(id)
        }
        return ordered
    }

    private func writeApnsTokenToProfile(id profileId: String, token: String) async -> Bool {
        guard await ensureProfileRowExists(profileId: profileId) else {
            print("🔴 [APNs] FAILURE — profile row ensure failed before token write id=\(profileId)")
            return false
        }

        let prefix = String(token.prefix(16))

        if let row = await upsertProfileAPNSWithRepresentation(profileId: profileId, token: token, context: "writeApnsToken") {
            if await confirmProfileTokenStored(profileId: profileId, tokenPrefix: prefix) {
                print("🟢 [APNs] SUCCESS upsert+read-back profiles.id=\"\(row.id)\" apns_token len=\(token.count)")
                return true
            }
            print("🔴 [APNs] upsert representation OK but read-back failed profiles.id=\"\(profileId)\"")
        }

        do {
            try await client
                .from("profiles")
                .update(ProfileAPNSUpdate(apnsToken: token))
                .eq("id", value: profileId)
                .execute()
            print("🟢 [APNs] PostgREST update HTTP OK profiles.id=\"\(profileId)\"")
            if await confirmProfileTokenStored(profileId: profileId, tokenPrefix: prefix) {
                print("🟢 [APNs] SUCCESS update+read-back profiles.id=\"\(profileId)\" apns_token len=\(token.count)")
                return true
            }
            SupabaseProfileWriteProbe.logSilentRLSBlock(context: "writeApnsToken UPDATE then SELECT miss", profileId: profileId)
        } catch {
            SupabaseProfileWriteProbe.logError(context: "profiles update id=\(profileId)", error: error)
        }

        if await insertProfileRowWithRepresentation(profileId: profileId, apnsToken: token, context: "writeApnsToken fallback INSERT") != nil {
            if await confirmProfileTokenStored(profileId: profileId, tokenPrefix: prefix) {
                print("🟢 [APNs] SUCCESS insert+read-back profiles.id=\"\(profileId)\" apns_token len=\(token.count)")
                return true
            }
        }

        print("🔴 [APNs] FAILURE profiles.id=\"\(profileId)\" — upsert/update/insert 모두 실패")
        return false
    }

    private func confirmProfileTokenStored(profileId: String, tokenPrefix: String) async -> Bool {
        let lookupIds = Array(Set([profileId, DeviceUserId.canonical(profileId)]))
        for lookupId in lookupIds {
            do {
                let rows: [UserProfile] = try await client
                    .from("profiles")
                    .select("id,apns_token")
                    .eq("id", value: lookupId)
                    .limit(1)
                    .execute()
                    .value

                guard let row = rows.first else { continue }
                guard let token = row.apnsToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
                    print("🔴 [APNs] read-back id=\(row.id) — apns_token 비어 있음")
                    continue
                }
                if tokenPrefix.count >= 8, !token.hasPrefix(tokenPrefix) {
                    print("⚠️ [APNs] read-back prefix 불일치 storedLen=\(token.count)")
                }
                print("🟢 [APNs] read-back OK profiles.id=\(row.id) tokenLen=\(token.count)")
                return true
            } catch {
                SupabaseProfileWriteProbe.logError(context: "read-back id=\(lookupId)", error: error)
            }
        }
        print("🔴 [APNs] read-back — profiles 행 없음 tried=\(lookupIds.joined(separator: ", "))")
        return false
    }

    /// `UIApplicationDelegate.didRegisterForRemoteNotificationsWithDeviceToken` → Supabase `profiles.apns_token`.
    /// Edge Function `recipient_id`는 `rooms.user1_id`/`user2_id`와 동일한 device id로 조회합니다.
    @discardableResult
    func saveDeviceTokenFromAPNs(_ deviceToken: Data) async -> Bool {
        let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        guard !hex.isEmpty else {
            print("🔴 [APNs] saveDeviceTokenFromAPNs — empty Data")
            return false
        }

        UserDefaults.standard.set(hex, forKey: Constants.lastAPNSTokenKey)

        guard await ensureAuthenticatedSessionForProfiles() else {
            print("🔴 [APNs] saveDeviceTokenFromAPNs — signInAnonymously/session 미완료")
            return false
        }

        await logPushRecipientIdAlignment(context: "saveDeviceTokenFromAPNs 시작")
        print("📲 [APNs] didRegister → Supabase save tokenLen=\(hex.count)")

        await ensureProfileRecordsForCurrentDevice()

        let saved: Bool
        if await updateAPNSToken(hex) {
            saved = true
        } else {
            print("⚠️ [APNs] 1차 저장 실패 — 0.8s 후 재시도")
            try? await Task.sleep(for: .milliseconds(800))
            saved = await updateAPNSToken(hex)
            if saved {
                print("🟢 [APNs] SUCCESS saveDeviceTokenFromAPNs (재시도 성공)")
            } else {
                print("🔴 [APNs] FAILURE saveDeviceTokenFromAPNs — profiles.apns_token 미저장")
            }
        }

        await logPushRecipientIdAlignment(context: saved ? "saveDeviceTokenFromAPNs 성공" : "saveDeviceTokenFromAPNs 실패")
        if !saved {
            _ = await runProfilesDatabaseWriteProbe(assumeAuthReady: false)
        }
        return saved
    }

    /// APNs device token(hex)을 `profiles.apns_token`에 upsert합니다.
    @discardableResult
    func updateAPNSToken(_ hexToken: String) async -> Bool {
        let trimmed = hexToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("🔴 [APNs] FAILURE — empty device token")
            return false
        }

        logProfileIdentityContext(phase: "updateAPNSToken 시작")

        guard await ensureAuthenticatedSessionForProfiles() else {
            print("🔴 [APNs] FAILURE — auth session/metadata 준비 실패")
            return false
        }
        logProfileIdentityContext(phase: "auth 준비 완료")

        UserDefaults.standard.set(trimmed, forKey: Constants.lastAPNSTokenKey)
        let profileIds = await resolvedProfileIdsForPushStorage()
        print("🔑 [APNs] profiles write targets: \(profileIds.joined(separator: " | "))")

        for profileId in profileIds {
            _ = await ensureProfileRowExists(profileId: profileId)
        }

        var savedAny = false
        var results: [String] = []
        for profileId in profileIds {
            if await writeApnsTokenToProfile(id: profileId, token: trimmed) {
                savedAny = true
                results.append("OK:\(profileId)")
            } else {
                results.append("FAIL:\(profileId)")
            }
        }
        print("📊 [APNs] write summary \(results.joined(separator: " | "))")

        if savedAny {
            print("🟢 [APNs] SUCCESS — apns_token 저장됨 primary=\(currentUserId)")
            return true
        }

        print("🔴 [APNs] FAILURE — profiles apns_token 저장 최종 실패 primary=\(currentUserId)")
        print("   → Supabase Anonymous auth + Docs/SupabaseAPNsProfiles.sql RLS 확인")
        return false
    }

    func syncCachedAPNSTokenIfNeeded() async {
        await logPushRecipientIdAlignment(context: "syncCachedAPNSToken (앱 실행)")
        await ensureProfileRecordsForCurrentDevice()

        logProfileIdentityContext(phase: "syncCachedAPNSToken")
        guard let cached = UserDefaults.standard.string(forKey: Constants.lastAPNSTokenKey),
              !cached.isEmpty else {
            print("⚠️ [APNs] 로컬 캐시 토큰 없음 — didRegisterForRemoteNotifications 후 saveDeviceTokenFromAPNs 호출 대기")
            return
        }
        print("🔔 [APNs] bootstrap/sync — 캐시 토큰으로 updateAPNSToken 호출 len=\(cached.count)")
        let ok = await updateAPNSToken(cached)
        if !ok {
            print("🔴 [APNs] FAILURE syncCachedAPNSToken — profiles apns_token 미저장")
        } else {
            await logPushRecipientIdAlignment(context: "syncCachedAPNSToken 성공")
        }
    }

    func verifyAPNSTokenPersisted(expectedPrefix: String) async {
        logProfileIdentityContext(phase: "verifyAPNSTokenPersisted")
        guard await ensureAuthenticatedSessionForProfiles() else { return }

        do {
            let profileId = currentUserId
            let profileRows: [UserProfile] = try await client
                .from("profiles")
                .select()
                .eq("id", value: profileId)
                .limit(1)
                .execute()
                .value

            guard let row = profileRows.first else {
                print("❌ [APNs] profiles 검증 — id=\(profileId) 행 없음 (upsert 재시도)")
                if let cached = UserDefaults.standard.string(forKey: Constants.lastAPNSTokenKey), !cached.isEmpty {
                    _ = await updateAPNSToken(cached)
                }
                return
            }

            if row.id != profileId {
                print("❌ [APNs] profiles 검증 — id 불일치 query=\(profileId) row=\(row.id)")
            }

            if let token = row.apnsToken, token.hasPrefix(expectedPrefix) {
                print("✅ [APNs] profiles 검증 OK id=\(profileId.prefix(8))… token prefix 일치")
            } else if row.apnsToken == nil || row.apnsToken?.isEmpty == true {
                print("❌ [APNs] profiles 검증 실패 — id=\(profileId.prefix(8))… apns_token 비어 있음")
            } else {
                print("⚠️ [APNs] profiles 검증 — id=\(profileId.prefix(8))… token prefix 불일치 (토큰 갱신됨?)")
            }
        } catch {
            SupabaseProfileWriteProbe.logError(context: "profiles verify read", error: error)
        }
    }

    private func notifyPartnerPush(for message: MediaMessage) async {
        guard let room = try? await refreshRoom(id: message.roomId) else {
            print("⚠️ [MessagePush] room 조회 실패 id=\(message.roomId)")
            return
        }
        await MessagePushService.send(message: message, room: room)
    }

    private static func makeInviteCode() -> String {
        String((0..<Constants.inviteCodeLength).map { _ in inviteCharacters.randomElement()! })
    }
}

/// Supabase `profiles` row (device user id + APNs token).
struct UserProfile: Codable, Identifiable, Equatable {
    let id: String
    let apnsToken: String?

    enum CodingKeys: String, CodingKey {
        case id
        case apnsToken = "apns_token"
    }
}

private struct ProfileRowInsert: Encodable {
    let id: String
    let apnsToken: String?

    enum CodingKeys: String, CodingKey {
        case id
        case apnsToken = "apns_token"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        if let apnsToken {
            try container.encode(apnsToken, forKey: .apnsToken)
        } else {
            try container.encodeNil(forKey: .apnsToken)
        }
    }
}

private struct ProfileAPNSUpsert: Encodable {
    let id: String
    let apnsToken: String

    enum CodingKeys: String, CodingKey {
        case id
        case apnsToken = "apns_token"
    }
}

private struct ProfileAPNSUpdate: Encodable {
    let apnsToken: String

    enum CodingKeys: String, CodingKey {
        case apnsToken = "apns_token"
    }
}
