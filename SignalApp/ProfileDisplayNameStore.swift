//
//  ProfileDisplayNameStore.swift
//  SignalApp
//

import Foundation

/// Apple/Google 계정에 묶인 기본 표시 이름 (채팅 입장과 무관).
enum ProfileDisplayNameStore {
    private static let key = "signal_app_profile_display_name"

    static var saved: String? {
        let primary = UserDefaults.standard.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let primary, !primary.isEmpty { return primary }
        let legacy = UserDefaults.standard.string(forKey: "signal_app_nickname")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let legacy, !legacy.isEmpty else { return nil }
        UserDefaults.standard.set(legacy, forKey: key)
        return legacy
    }

    static var hasValid: Bool {
        guard let saved else { return false }
        return NicknameValidator.isValid(saved)
    }

    static func save(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: key)
        UserDefaults.standard.set(trimmed, forKey: "signal_app_nickname")
    }
}
