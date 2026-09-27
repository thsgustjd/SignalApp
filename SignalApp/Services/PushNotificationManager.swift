//
//  PushNotificationManager.swift
//  SignalApp
//

import Foundation
import UIKit
import UserNotifications

/// APNs device token 등록 · Supabase `profiles.apns_token` 동기화.
enum PushNotificationManager {
    private static let manager = SupabaseManager.shared

    /// `AppDelegate`에서 1회만 호출 (ContentView 중복 호출 금지 — register 레이스 방지).
    static func bootstrap() async {
        print("🔔 [Push] bootstrap start")
        await NotificationAuthorizationService.configurePushNotifications()

        guard await manager.ensureAuthenticatedSessionForProfiles() else {
            print("🔴 [Push] bootstrap 중단 — Anonymous Auth 세션 미완료")
            await logAuthorizationStatus()
            return
        }

        let probeOK = await manager.runProfilesDatabaseWriteProbe(assumeAuthReady: true)
        if !probeOK {
            print("🔴 [Push] Profiles Probe 실패 — RLS/SQL 확인 (콘솔 PostgrestError code=42501)")
        }

        await manager.logPushRecipientIdAlignment(context: "appLaunch bootstrap")
        await manager.ensureProfileRecordsForCurrentDevice()
        await manager.syncCachedAPNSTokenIfNeeded()
        await logAuthorizationStatus()
        print("🔔 [Push] bootstrap end")
    }

    static func refreshRegistrationAndSyncToken() async {
        await NotificationAuthorizationService.registerForRemoteNotificationsIfAuthorized()
        _ = await manager.ensureAuthenticatedSessionForProfiles()
        await manager.ensureProfileRecordsForCurrentDevice()
        await manager.syncCachedAPNSTokenIfNeeded()
    }

    /// `AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken` — signIn 완료 후 Supabase 저장.
    static func handleRegisteredDeviceToken(_ deviceToken: Data) async {
        PushNotificationDiagnostics.logDeviceToken(deviceToken)

        let saved = await manager.saveDeviceTokenFromAPNs(deviceToken)
        if saved {
            let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
            await manager.verifyAPNSTokenPersisted(expectedPrefix: String(hex.prefix(16)))
            await manager.logPushRecipientIdAlignment(context: "didRegister 저장 성공")
            print("🟢 [Push] didRegister → Supabase profiles.apns_token 저장 완료")
        } else {
            await manager.logPushRecipientIdAlignment(context: "didRegister 저장 실패")
            print("🔴 [Push] didRegister → Supabase 저장 실패")
        }
    }

    static func logAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        PushNotificationDiagnostics.logNotificationSettings(settings, prefix: "최종 권한")
        await MainActor.run {
            print("📲 [Push] UIApplication.isRegisteredForRemoteNotifications=\(UIApplication.shared.isRegisteredForRemoteNotifications)")
        }
    }

    static func handleRegistrationFailure(_ error: Error) {
        PushNotificationDiagnostics.logRegistrationFailure(error)
    }
}
