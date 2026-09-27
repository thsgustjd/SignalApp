//
//  ChatIncomingNotifications.swift
//  SignalApp
//

import AudioToolbox
import Foundation
import UIKit
import UserNotifications

enum IncomingHapticFeedback {
    static func playKeycapTap() {
        AudioServicesPlaySystemSound(1519)
    }

    static func playEmergencyAlarm() {
        AudioServicesPlaySystemSound(1520)
        AudioServicesPlaySystemSound(1520)
        AudioServicesPlaySystemSound(1520)
    }
}

enum ChatIncomingNotifications {
    static func nudgeBannerText(content: String?, senderName: String) -> String {
        let body = AppGroupStorage.keycapDisplayText(fromNudgeContent: content)
        let name = senderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return body }
        return "\(name): \(body)"
    }

    /// Realtime 수신용 — 실기기 로컬 알림은 격자 아이콘 이슈로 기본 비활성.
    /// 시뮬레이터에서만 원격 APNs 대체 테스트용 로컬 알림 허용.
    static func scheduleLocalNotification(for message: MediaMessage, partnerName: String) {
        #if targetEnvironment(simulator)
        scheduleSimulatorFallbackNotification(for: message, partnerName: partnerName)
        #else
        _ = message
        _ = partnerName
        #endif
    }

    #if targetEnvironment(simulator)
    private static func scheduleSimulatorFallbackNotification(for message: MediaMessage, partnerName: String) {
        let isEmergency = message.type == AppGroupStorage.emergencyNudgeType
        guard isEmergency || !AppGroupStorage.isSignalDNDActive else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = RoomPushTitleCache.pushAlertTitle(
            roomId: message.roomId,
            senderNickname: partnerName
        )

        switch message.type {
        case AppGroupStorage.emergencyNudgeType:
            content.body = "\(partnerName) — 비상 연락"
        case "nudge":
            content.body = AppGroupStorage.keycapDisplayText(fromNudgeContent: message.content)
        case "drawing":
            content.body = "\(partnerName) 님이 그림을 보냈어요"
        case "photo":
            content.body = "\(partnerName) 님이 사진을 보냈어요"
        default:
            if let text = message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                content.body = text
            } else {
                content.body = partnerName
            }
        }

        let request = UNNotificationRequest(
            identifier: "sim-fallback-\(message.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("🔴 [Push] Simulator local fallback failed: \(error.localizedDescription)")
            } else {
                print("🟡 [Push] Simulator local fallback scheduled type=\(message.type)")
            }
        }
    }
    #endif
}

enum NotificationAuthorizationService {
    static func configurePushNotifications() async {
        PushNotificationDiagnostics.logRuntimeEnvironment()
        await requestAuthorizationIfNeeded()
        await registerForRemoteNotificationsIfAuthorized()
    }

    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings()
        PushNotificationDiagnostics.logNotificationSettings(settings, prefix: "권한 상태(요청 전)")

        if settings.authorizationStatus == .notDetermined {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                settings = await center.notificationSettings()
                print("🔔 [Push] requestAuthorization finished granted=\(granted)")
                PushNotificationDiagnostics.logNotificationSettings(settings, prefix: "권한 상태(요청 후)")
            } catch {
                print("🔴 [Push] requestAuthorization error: \(error.localizedDescription)")
            }
        } else {
            print("🔔 [Push] requestAuthorization skip — already \(PushNotificationDiagnostics.authorizationStatusLabel(settings.authorizationStatus))")
        }

        switch settings.authorizationStatus {
        case .denied:
            print("🔴 [Push] 알림 거부됨 — 설정 → ㄱ.정병키캡 → 알림 허용")
        case .authorized, .provisional, .ephemeral:
            print("🟢 [Push] 알림 권한 OK — remote registration 진행")
        default:
            print("⚠️ [Push] 알림 권한 미확정 — remote registration 생략될 수 있음")
        }
    }

    static func registerForRemoteNotificationsIfAuthorized() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            await MainActor.run {
                PushNotificationDiagnostics.logRemoteRegistrationAttempt()
                UIApplication.shared.registerForRemoteNotifications()
            }
        default:
            print(
                "⚠️ [Push] registerForRemoteNotifications SKIP — authorization=\(PushNotificationDiagnostics.authorizationStatusLabel(settings.authorizationStatus))"
            )
        }
    }
}
