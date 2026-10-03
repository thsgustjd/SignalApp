//
//  HeartQuotaStorage.swift
//  SignalApp + SignalWidgetExtension
//

import Foundation

private enum HeartQuotaKeys {
    static let dailyFreeRemaining = "heartDailyFreeRemaining"
    static let unlimitedUntilISO = "heartUnlimitedUntilISO"
}

private enum HeartQuotaDefaults {
    static var store: UserDefaults? {
        guard AppGroupConfig.isContainerAvailable else { return nil }
        return UserDefaults(suiteName: AppGroupConfig.suiteName)
    }
}

extension AppGroupStorage {
    static var heartDailyFreeRemaining: Int {
        get {
            let store = HeartQuotaDefaults.store
            let value = store?.integer(forKey: HeartQuotaKeys.dailyFreeRemaining) ?? 0
            if value == 0, store?.object(forKey: HeartQuotaKeys.dailyFreeRemaining) == nil {
                return HeartEconomyConstants.dailyFreeAllowance
            }
            return value
        }
        set {
            HeartQuotaDefaults.store?.set(newValue, forKey: HeartQuotaKeys.dailyFreeRemaining)
        }
    }

    static var heartUnlimitedUntil: Date? {
        get {
            guard let raw = HeartQuotaDefaults.store?.string(forKey: HeartQuotaKeys.unlimitedUntilISO) else {
                return nil
            }
            return ISO8601DateFormatter().date(from: raw)
        }
        set {
            guard let store = HeartQuotaDefaults.store else { return }
            if let newValue {
                store.set(
                    ISO8601DateFormatter().string(from: newValue),
                    forKey: HeartQuotaKeys.unlimitedUntilISO
                )
            } else {
                store.removeObject(forKey: HeartQuotaKeys.unlimitedUntilISO)
            }
        }
    }

    static var heartUnlimitedActive: Bool {
        guard let until = heartUnlimitedUntil else { return false }
        return until > Date()
    }

    static func syncHeartQuota(dailyFreeRemaining: Int, unlimitedUntil: Date?) {
        heartDailyFreeRemaining = dailyFreeRemaining
        heartUnlimitedUntil = unlimitedUntil
    }

    static func canConsumeHeartQuotaLocally() -> Bool {
        if heartUnlimitedActive { return true }
        return heartDailyFreeRemaining > 0
    }

    static func consumeHeartQuotaLocallyIfNeeded() {
        if heartUnlimitedActive { return }
        heartDailyFreeRemaining = max(0, heartDailyFreeRemaining - 1)
    }
}
