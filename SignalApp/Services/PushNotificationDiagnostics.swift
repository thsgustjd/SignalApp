//
//  PushNotificationDiagnostics.swift
//  SignalApp
//

import Foundation
import UIKit
import UserNotifications

enum PushNotificationDiagnostics {
    static func logRuntimeEnvironment() {
        #if targetEnvironment(simulator)
        print(
            """
            📱 [Push] runtime=SIMULATOR — 원격 APNs는 Xcode·macOS·Apple ID 설정에 따라 실패할 수 있음.
            실기기에서 didRegister + profiles 토큰 + Edge Function 테스트 권장.
            """
        )
        #else
        print("📱 [Push] runtime=DEVICE — APNs development(디버그) / production(Release) entitlements 확인")
        #endif

        #if DEBUG
        print("📱 [Push] build=DEBUG → Edge Function APNS_USE_SANDBOX=true 필요")
        #else
        print("📱 [Push] build=RELEASE → Edge Function APNS_USE_SANDBOX=false")
        #endif
    }

    static func authorizationStatusLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined(0)"
        case .denied: return "denied(1)"
        case .authorized: return "authorized(2)"
        case .provisional: return "provisional(3)"
        case .ephemeral: return "ephemeral(4)"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }

    static func logNotificationSettings(_ settings: UNNotificationSettings, prefix: String) {
        print(
            """
            🔔 [Push] \(prefix)
            authorization=\(authorizationStatusLabel(settings.authorizationStatus))
            alert=\(settings.alertSetting.rawValue) sound=\(settings.soundSetting.rawValue) badge=\(settings.badgeSetting.rawValue)
            lockScreen=\(settings.lockScreenSetting.rawValue) notificationCenter=\(settings.notificationCenterSetting.rawValue)
            """
        )
    }

    static func logRemoteRegistrationAttempt() {
        let app = UIApplication.shared
        print("📲 [Push] registerForRemoteNotifications() 호출 (isRegistered=\(app.isRegisteredForRemoteNotifications))")
    }

    static func logDeviceToken(_ deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        let preview = hex.prefix(32)
        print("✅ [APNs] Device Token 수신 len=\(hex.count) hexPrefix=\(preview)…")
        #if targetEnvironment(simulator)
        print("✅ [APNs] Simulator token — 서버 sandbox와 번들 ID가 맞아야 Edge→APNs 성공")
        #endif
    }

    static func logRegistrationFailure(_ error: Error) {
        let ns = error as NSError
        print(
            """
            🔴 [APNs] didFailToRegisterForRemoteNotifications
            domain=\(ns.domain) code=\(ns.code)
            description=\(error.localizedDescription)
            """
        )
        #if targetEnvironment(simulator)
        print(
            """
            🔴 [APNs] Simulator 흔한 원인: Push Capability 미설정, 네트워크, iOS 버전.
            시뮬레이터에서는 Realtime + 앱 내 배너로 메시지 확인 가능.
            """
        )
        #endif
    }
}
