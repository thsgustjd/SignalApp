//
//  AppDelegate.swift
//  SignalApp
//

import AudioToolbox
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        PushNotificationCategories.registerIfNeeded()
        PushNotificationAppIconDiagnostics.logMainBundleIconMetadata()
        AppAudioSession.configureForInAppSounds()
        KeycapPressFeedback.prepare()
        BipbiIncomingSound.prepare()

        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            Task { @MainActor in
                PushNotificationRouter.shared.handleNotificationTap(userInfo: remote)
            }
        }

        Task {
            await PushNotificationManager.bootstrap()
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AppAudioSession.configureForInAppSounds()
        KeycapPressFeedback.prepare()
        BipbiIncomingSound.prepare()
        Task {
            await PushNotificationManager.refreshRegistrationAndSyncToken()
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // APNs 토큰 → Supabase profiles.apns_token (PushNotificationManager → SupabaseManager.saveDeviceTokenFromAPNs)
        Task {
            await PushNotificationManager.handleRegisteredDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationManager.handleRegistrationFailure(error)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let triggerRemote = notification.request.trigger is UNPushNotificationTrigger

        if triggerRemote {
            let host = userInfo["host_bundle_id"] as? String ?? userInfo["bundle_id"] as? String ?? "?"
            print("🔔 [Push] willPresent remote host_bundle_id=\(host) category=\(notification.request.content.categoryIdentifier)")
        }

        let messageType = userInfo["message_type"] as? String
        let isEmergencyPush = messageType == AppGroupStorage.emergencyNudgeType

        if AppGroupStorage.isSignalDNDActive && !isEmergencyPush {
            completionHandler([])
            return
        }

        if let senderId = userInfo["sender_id"] as? String,
           UserSafetyStore.isBlocked(senderId) {
            completionHandler([])
            return
        }

        guard notification.request.trigger is UNPushNotificationTrigger else {
            completionHandler([])
            return
        }

        let pushContent = userInfo["content"] as? String
        if isEmergencyPush {
            IncomingHapticFeedback.playEmergencyAlarm()
        } else if BipbiPagerEasterEgg.isBipbiNudgeContent(pushContent) {
            BipbiIncomingSound.play()
        } else {
            IncomingHapticFeedback.playKeycapTap()
        }

        Task { @MainActor in
            PushNotificationRouter.shared.handleForegroundPresentation(userInfo: userInfo)
        }

        if BipbiPagerEasterEgg.isBipbiNudgeContent(pushContent) {
            completionHandler([.banner, .badge])
        } else {
            completionHandler([.banner, .sound, .badge])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            PushNotificationRouter.shared.handleNotificationTap(userInfo: userInfo)
            completionHandler()
        }
    }
}
