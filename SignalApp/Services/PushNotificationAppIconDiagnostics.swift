//
//  PushNotificationAppIconDiagnostics.swift
//  SignalApp
//

import Foundation

enum PushNotificationAppIconDiagnostics {
    /// 원격 푸시 배너 아이콘 = 메인 앱 AppIcon. 회색 격자 = 커뮤니케이션 알림 placeholder 또는 CFBundleIcons 누락.
    static func logMainBundleIconMetadata() {
        let bundle = Bundle.main
        let bundleId = bundle.bundleIdentifier ?? "MISSING"
        let iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconName") as? String
        let icons = bundle.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primaryIcon = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let primaryName = primaryIcon?["CFBundleIconName"] as? String
        let plistHost = bundle.object(forInfoDictionaryKey: "SignalHostApplicationBundleIdentifier") as? String

        let idOK = bundleId == PushNotificationHostConfig.mainAppBundleIdentifier
        let iconOK = iconName == PushNotificationHostConfig.iconAssetCatalogName

        print(
            """
            🖼 [Push Icon] PRODUCT bundleId=\(bundleId) expected=\(PushNotificationHostConfig.mainAppBundleIdentifier) match=\(idOK)
            CFBundleIconName=\(iconName ?? "MISSING") primary=\(primaryName ?? "MISSING") iconOK=\(iconOK)
            SignalHostApplicationBundleIdentifier(plist)=\(plistHost ?? "nil")
            AppGroup=\(PushNotificationHostConfig.appGroupIdentifier) container=\(AppGroupConfig.isContainerAvailable)
            ℹ️ APNs apns-topic must equal main bundleId; alert subtitle 없음 → 앱 아이콘 배너
            """
        )

        if !idOK {
            print("🔴 [Push Icon] Bundle ID 불일치 — Xcode PRODUCT_BUNDLE_IDENTIFIER 확인")
        }
        if !iconOK {
            print("🔴 [Push Icon] CFBundleIconName ≠ AppIcon — Assets + INFOPLIST_KEY_CFBundleIconName 확인")
        }
    }
}
