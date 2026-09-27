//
//  PushNotificationCategories.swift
//  SignalApp
//

import UserNotifications

/// Edge Function `send-message-push` 의 `aps.category` 와 동일해야 합니다.
enum PushNotificationCategories {
    static let message = "SIGNAL_MESSAGE"
    static let richMedia = "SIGNAL_RICH_MEDIA"

    static func registerIfNeeded() {
        let messageCategory = UNNotificationCategory(
            identifier: message,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let richCategory = UNNotificationCategory(
            identifier: richMedia,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([messageCategory, richCategory])
    }
}
