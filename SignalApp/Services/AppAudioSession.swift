//
//  AppAudioSession.swift
//  SignalApp
//

import AVFoundation

/// 앱 내 키캡·삐삐 등 UI 효과음 — 하드웨어 무음 스위치와 무관하게 재생.
enum AppAudioSession {
    static func configureForInAppSounds() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            #if DEBUG
            print("⚠️ [AppAudioSession] \(error.localizedDescription)")
            #endif
        }
    }
}
