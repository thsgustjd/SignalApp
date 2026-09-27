//
//  AppGroupConfig.swift
//  SignalApp + SignalWidgetExtension
//
//  App Group 식별자는 코드·entitlements에서 동일해야 합니다.
//  - SignalApp/SignalApp.entitlements
//  - SignalWidgetExtension.entitlements
//  - NotificationService/NotificationService.entitlements
//  - NotificationContentUI/NotificationContentUI.entitlements
//

import Foundation

enum AppGroupConfig {
    /// App Group ID — entitlements의 `com.apple.security.application-groups`와 **완전히 동일**해야 합니다.
    static let suiteName = "group.com.hs.SignalApp"

    /// 현재 프로세스에 App Group 컨테이너가 마운트되어 있는지 (권한·프로비저닝 확인용).
    static var isContainerAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) != nil
    }
}
