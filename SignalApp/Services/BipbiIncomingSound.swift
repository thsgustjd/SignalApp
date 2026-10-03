//
//  BipbiIncomingSound.swift
//  SignalApp
//

import AVFoundation

/// 삐삐 암호 넛지 수신 시 재생 (UI 없음).
enum BipbiIncomingSound {
    private static let resourceName = "bippibippisound"
    private static let resourceExtension = "wav"

    private static var player: AVAudioPlayer?

    static func prepare() {
        _ = loadPlayer()
    }

    static func playIfBipbiNudge(content: String?) {
        guard BipbiPagerEasterEgg.isBipbiNudgeContent(content) else { return }
        play()
    }

    static func play() {
        guard let player = loadPlayer() else { return }
        configureSessionIfNeeded()
        player.currentTime = 0
        player.play()
    }

    private static func loadPlayer() -> AVAudioPlayer? {
        if let player { return player }
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) else {
            return nil
        }
        guard let loaded = try? AVAudioPlayer(contentsOf: url) else { return nil }
        loaded.prepareToPlay()
        loaded.volume = 1
        player = loaded
        return loaded
    }

    private static func configureSessionIfNeeded() {
        AppAudioSession.configureForInAppSounds()
    }
}
