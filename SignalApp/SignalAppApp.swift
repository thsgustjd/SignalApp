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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(PushNotificationRouter.shared)
        }
    }
}
