//
//  RoomPushTitleFormatter.swift
//  NotificationService
//

import Foundation
import UserNotifications

/// 수신 기기 App Group에 저장된 방 이름 + 발신 닉네임 → `방이름-보낸사람`.
enum RoomPushTitleFormatter {
    private static let appGroupSuite = "group.com.hs.SignalApp"
    private static let profilesKey = "signal_room_local_profiles"
    private static let defaultTitlesKey = "signal_room_default_display_titles"

    private struct Profile: Decodable {
        let title: String
        let emoji: String?
    }

    static func apply(to content: UNMutableNotificationContent) {
        let info = content.userInfo
        guard let roomIdString = info["room_id"] as? String,
              let roomId = UUID(uuidString: roomIdString) else {
            return
        }
        let sender = (info["sender_nickname"] as? String) ?? ""
        content.title = format(roomId: roomId, senderNickname: sender)
    }

    private static func format(roomId: UUID, senderNickname: String) -> String {
        let roomTitle = resolvedRoomTitle(roomId: roomId)
        let sender = senderNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if sender.isEmpty { return roomTitle }
        return "\(roomTitle)-\(sender)"
    }

    private static func resolvedRoomTitle(roomId: UUID) -> String {
        if let custom = loadProfiles()[roomId.uuidString]?.title.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        if let cached = loadDefaultTitles()[roomId.uuidString]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !cached.isEmpty {
            return cached
        }
        return "채팅방"
    }

    private static func loadProfiles() -> [String: Profile] {
        guard let defaults = UserDefaults(suiteName: appGroupSuite),
              let data = defaults.data(forKey: profilesKey),
              let decoded = try? JSONDecoder().decode([String: Profile].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func loadDefaultTitles() -> [String: String] {
        guard let defaults = UserDefaults(suiteName: appGroupSuite),
              let data = defaults.data(forKey: defaultTitlesKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
