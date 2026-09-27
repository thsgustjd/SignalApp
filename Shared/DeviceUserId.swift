//
//  DeviceUserId.swift
//  SignalApp + SignalWidgetExtension
//

import Foundation

/// 앱 전역 device user id — `rooms.user1_id` / `user2_id` / `messages.sender_id` / `profiles.id` 와 동일 체계.
enum DeviceUserId {
    /// UUID 문자열을 소문자로 통일 (Postgres text 비교·Edge Function 조회 일치).
    static func canonical(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func matches(_ a: String, _ b: String) -> Bool {
        canonical(a) == canonical(b)
    }
}
