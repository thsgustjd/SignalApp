//
//  KeycapPressFeedback.swift
//  SignalApp
//

import AVFoundation
import UIKit

/// 앱 내 키캡 누름 — 기계식 클릭음 + 햅틱 (수신 알림용 `IncomingHapticFeedback` 과 분리).
enum KeycapPressFeedback {
    /// `KeycapClick.wav` 선행 구간(10ms) 뒤 타격 피크 — 햅틱을 그 시점에 맞춤.
    private static let transientAlignDelay: TimeInterval = 0.010

    private static let clickVolume: Float = 0.21
    private static let lightClickVolume: Float = 0.15
    private static let pressHapticIntensity: CGFloat = 0.56
    private static let lightHapticIntensity: CGFloat = 0.38

    private static var impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static var lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private static var clickPlayer: AVAudioPlayer?
    private static var didPrepareAudio = false

    static func prepare() {
        impactGenerator.prepare()
        lightImpactGenerator.prepare()
        configureAudioSessionIfNeeded()
        loadClickPlayerIfNeeded()
        clickPlayer?.prepareToPlay()
    }

    /// 그리드 키캡 눌림 시작 — 타건 피크와 햅틱 동시(오디오 출력 지연 보정).
    static func playPress(intensity: CGFloat? = nil) {
        let amount = intensity ?? pressHapticIntensity
        playAlignedClick(volume: clickVolume) {
            impactGenerator.impactOccurred(intensity: amount)
            impactGenerator.prepare()
        }
    }

    /// 비상 연타 등 가벼운 입력.
    static func playPressLight() {
        playAlignedClick(volume: lightClickVolume) {
            lightImpactGenerator.impactOccurred(intensity: lightHapticIntensity)
            lightImpactGenerator.prepare()
        }
    }

    private static func playAlignedClick(volume: Float, haptic: @escaping () -> Void) {
        playClick(volume: volume)
        DispatchQueue.main.asyncAfter(deadline: .now() + transientAlignDelay) {
            haptic()
        }
    }

    private static func playClick(volume: Float) {
        guard let clickPlayer else { return }
        clickPlayer.volume = volume
        if clickPlayer.isPlaying {
            clickPlayer.stop()
        }
        clickPlayer.currentTime = 0
        clickPlayer.play()
    }

    private static func configureAudioSessionIfNeeded() {
        guard !didPrepareAudio else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            didPrepareAudio = true
        } catch {
            #if DEBUG
            print("⚠️ [KeycapPressFeedback] AVAudioSession: \(error.localizedDescription)")
            #endif
        }
    }

    private static func loadClickPlayerIfNeeded() {
        guard clickPlayer == nil,
              let url = Bundle.main.url(forResource: "KeycapClick", withExtension: "wav") else {
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = clickVolume
            player.numberOfLoops = 0
            player.enableRate = false
            clickPlayer = player
        } catch {
            #if DEBUG
            print("⚠️ [KeycapPressFeedback] KeycapClick.wav: \(error.localizedDescription)")
            #endif
        }
    }
}
