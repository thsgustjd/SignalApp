//
//  UserSafetyStore.swift
//  SignalApp
//

import Foundation

/// 로컬 차단 목록 — 수신 메시지·푸시 필터.
enum UserSafetyStore {
    private static let blockedEntriesKey = "signal_blocked_user_entries"

    struct BlockedEntry: Codable, Equatable, Identifiable {
        let userId: String
        let displayName: String

        var id: String { userId }
    }

    static func isBlocked(_ userId: String) -> Bool {
        guard !userId.isEmpty else { return false }
        return entries.contains { DeviceUserId.matches($0.userId, userId) }
    }

    static var entries: [BlockedEntry] {
        guard let data = UserDefaults.standard.data(forKey: blockedEntriesKey),
              let decoded = try? JSONDecoder().decode([BlockedEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    static func block(userId: String, displayName: String) {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? "사용자" : trimmedName
        var list = entries.filter { !DeviceUserId.matches($0.userId, userId) }
        list.append(BlockedEntry(userId: userId, displayName: name))
        persist(list)
    }

    static func unblock(userId: String) {
        let list = entries.filter { !DeviceUserId.matches($0.userId, userId) }
        persist(list)
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: blockedEntriesKey)
    }

    static func displayName(for userId: String) -> String? {
        entries.first { DeviceUserId.matches($0.userId, userId) }?.displayName
    }

    private static func persist(_ list: [BlockedEntry]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: blockedEntriesKey)
        }
    }
}
