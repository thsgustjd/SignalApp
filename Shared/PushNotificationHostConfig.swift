//
//  PushNotificationHostConfig.swift
//  SignalApp + extensions (Shared)
//

import Foundation

/// APNs `apns-topic` / Edge `host_bundle_id` / Xcode `PRODUCT_BUNDLE_IDENTIFIER`(메인) 와 **동일**해야 합니다.
enum PushNotificationHostConfig {
    static let mainAppBundleIdentifier = "com.hyunseong.SignalApp"
    static let appGroupIdentifier = AppGroupConfig.suiteName
    static let iconAssetCatalogName = "AppIcon"
}
