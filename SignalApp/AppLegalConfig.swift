//
//  AppLegalConfig.swift
//  SignalApp
//

import Foundation

/// App Store Connect · 앱 내 링크와 동일한 URL로 맞춥니다.
enum AppLegalConfig {
    /// GitHub Pages: `docs/legal` 배포 후 본인 URL로 수정 (README: docs/legal/README.md)
    private static let legalSiteBase = "https://thsgustjd.github.io/SignalApp/legal"

    static let supportEmail = "duftlaglehsdmfqjfwk@gmail.com"

    static var privacyPolicyURL: URL? {
        URL(string: "\(legalSiteBase)/privacy.html")
    }

    static var termsOfServiceURL: URL? {
        URL(string: "\(legalSiteBase)/terms.html")
    }

    static var developerStoryURL: URL? {
        URL(string: "\(legalSiteBase)/developer-story.html")
    }
}
