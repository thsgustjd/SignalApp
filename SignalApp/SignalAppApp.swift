//
//  SignalAppApp.swift
//  SignalApp
//
//  Created by 손현성 on 9/25/26.
//

import SwiftUI

@main
struct SignalAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authSession = AuthSessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(PushNotificationRouter.shared)
                .environmentObject(authSession)
                .dismissKeyboardOnBackgroundTap()
                .task { await authSession.bootstrap() }
                .onOpenURL { url in
                    Task { await authSession.handleOAuthCallback(url: url) }
                }
        }
    }
}
