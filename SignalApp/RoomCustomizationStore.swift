//
//  RoomCustomizationStore.swift
//  SignalApp
//

import Foundation

/// 채팅방별 로컬 표시 이름·대표 이모지 (닉네임·Supabase `rooms`와 분리).
enum RoomCustomizationStore {
    struct Profile: Codable, Equatable {
        var title: String
        var emoji: String
    }

    private static let storageKey = "signal_room_local_profiles"
    private static let migratedToAppGroupKey = "signal_room_profiles_migrated_to_app_group"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroupConfig.suiteName) ?? .standard
    }

    static func profile(for roomId: UUID) -> Profile? {
        migrateFromStandardUserDefaultsIfNeeded()
        return loadAll()[roomId.uuidString]
    }

    static func save(_ profile: Profile, for roomId: UUID) {
        var all = loadAll()
        let title = sanitizedTitle(profile.title)
        let emoji = primaryEmoji(from: profile.emoji)
        guard !title.isEmpty else { return }
        all[roomId.uuidString] = Profile(title: title, emoji: emoji)
        persist(all)
    }

    static func remove(for roomId: UUID) {
        var all = loadAll()
        all.removeValue(forKey: roomId.uuidString)
        persist(all)
    }

    static func sanitizedTitle(_ input: String) -> String {
        String(input.trimmingCharacters(in: .whitespacesAndNewlines).prefix(32))
    }

    static func canSubmitTitle(_ title: String) -> Bool {
        !sanitizedTitle(title).isEmpty
    }

    /// 입력 중 이모지 필드 — 첫 이모지 그래프 클러스터만 유지. 빈 문자열 허용(편집·삭제).
    static func sanitizedEmojiInput(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        for character in trimmed {
            if isEmojiLike(character) {
                return String(character)
            }
        }
        return ""
    }

    static func primaryEmoji(from input: String) -> String {
        let picked = sanitizedEmojiInput(input)
        return picked.isEmpty ? defaultEmojiSymbol : picked
    }

    static let defaultEmojiSymbol = "💬"

    static func isEmojiLike(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation || scalar.properties.isEmoji
        }
    }

    private static func loadAll() -> [String: Profile] {
        migrateFromStandardUserDefaultsIfNeeded()
        guard let data = defaults.data(forKey: storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: Profile].self, from: data)) ?? [:]
    }

    private static func persist(_ all: [String: Profile]) {
        guard let data = try? JSONEncoder().encode(all) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func migrateFromStandardUserDefaultsIfNeeded() {
        guard !defaults.bool(forKey: migratedToAppGroupKey) else { return }
        if let legacy = UserDefaults.standard.data(forKey: storageKey) {
            defaults.set(legacy, forKey: storageKey)
        }
        defaults.set(true, forKey: migratedToAppGroupKey)
    }
}

// MARK: - Push 알림 제목 (수신 기기 App Group · Notification Service Extension)

enum RoomPushTitleCache {
    private static let defaultTitlesKey = "signal_room_default_display_titles"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConfig.suiteName)
    }

    /// 멤버 구성 기준 기본 방 이름 — 커스텀 제목 없을 때 푸시·위젯용.
    static func syncDefaultDisplayTitle(_ title: String, for roomId: UUID) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let defaults else { return }
        var map = loadDefaultTitles()
        map[roomId.uuidString] = trimmed
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: defaultTitlesKey)
        }
    }

    /// 발송 측 Edge Function용 — 이 기기에서 보이는 방 이름.
    static func resolvedDisplayTitle(for roomId: UUID, fallbackDefault: String) -> String {
        if let custom = RoomCustomizationStore.profile(for: roomId)?.title {
            let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let cached = loadDefaultTitles()[roomId.uuidString]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached, !cached.isEmpty { return cached }
        let fb = fallbackDefault.trimmingCharacters(in: .whitespacesAndNewlines)
        return fb.isEmpty ? "채팅방" : fb
    }

    /// APNs 배너 **볼드 제목** — `방이름-보낸사람`.
    static func pushAlertTitle(roomId: UUID, senderNickname: String) -> String {
        let roomTitle = resolvedDisplayTitle(for: roomId, fallbackDefault: "채팅방")
        let sender = senderNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if sender.isEmpty { return roomTitle }
        return "\(roomTitle)-\(sender)"
    }

    private static func loadDefaultTitles() -> [String: String] {
        guard let defaults,
              let data = defaults.data(forKey: defaultTitlesKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
