//
//  KeycapPressFeedback.swift
//  SignalApp
//

import AVFoundation
import UIKit

/// 앱 내 키캡 누름 — 랜덤 타건 MP3 + 햅틱 (수신 알림용 `IncomingHapticFeedback` 과 분리).
enum KeycapPressFeedback {
    static let clickFileCount = 15

    /// Resources/click1.mp3 … click15.mp3
    private static let randomClickBasenames = (1...clickFileCount).map { "click\($0)" }
    private static let clickFileExtension = "mp3"
    /// 파일당 동시 재생 슬롯 (0.1s 타건 × 연타).
    private static let instancesPerClickFile = 3
    /// 어떤 파일이든 재생 중이 아닌 슬롯 — 연타 스필오버용.
    private static let spilloverVoiceCount = 6

    /// 타건과 햅틱 정렬 — 짧을수록 터치 직후 손맛이 빨리 옵니다.
    private static let transientAlignDelay: TimeInterval = 0.004

    /// `AVAudioPlayer.volume` 최대 1.0
    private static let clickVolume: Float = 1.0
    private static let lightClickVolume: Float = 0.88
    private static let pressHapticIntensity: CGFloat = 0.56
    private static let lightHapticIntensity: CGFloat = 0.38

    private static var impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static var lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)

    private struct ClickVoice {
        let basename: String
        let player: AVAudioPlayer
    }

    /// click1 … click15 순으로 로드된 보이스 (파일당 `instancesPerClickFile`개).
    private static var voicesByFile: [[ClickVoice]] = []
    private static var spilloverVoices: [ClickVoice] = []
    private static var allVoices: [ClickVoice] = []
    private static var roundRobinByFile: [Int] = []
    private static var globalRoundRobin = 0

    private static var legacyFallbackPlayers: [AVAudioPlayer] = []
    private static var didPrepareAudio = false
    private static var didLoadPlayers = false

    static func prepare() {
        impactGenerator.prepare()
        lightImpactGenerator.prepare()
        configureAudioSessionIfNeeded()
        loadPlayerPoolIfNeeded()
        for voice in allVoices {
            voice.player.prepareToPlay()
        }
        for voice in spilloverVoices {
            voice.player.prepareToPlay()
        }
        for player in legacyFallbackPlayers {
            player.prepareToPlay()
        }
    }

    static func playPress(intensity: CGFloat? = nil) {
        let amount = intensity ?? pressHapticIntensity
        playAlignedClick(volume: clickVolume) {
            impactGenerator.impactOccurred(intensity: amount)
            impactGenerator.prepare()
        }
    }

    static func playPressLight() {
        playAlignedClick(volume: lightClickVolume) {
            lightImpactGenerator.impactOccurred(intensity: lightHapticIntensity)
            lightImpactGenerator.prepare()
        }
    }

    private static func playAlignedClick(volume: Float, haptic: @escaping () -> Void) {
        playRandomClick(volume: volume)
        DispatchQueue.main.asyncAfter(deadline: .now() + transientAlignDelay) {
            haptic()
        }
    }

    private static func playRandomClick(volume: Float) {
        guard !voicesByFile.isEmpty else {
            playFromLegacyPool(volume: volume)
            return
        }

        let preferredFileIndex = Int.random(in: 0..<voicesByFile.count)

        if playIdle(in: voicesByFile[preferredFileIndex], volume: volume) {
            return
        }

        if roundRobinInFile(preferredFileIndex, volume: volume) {
            return
        }

        for (index, row) in voicesByFile.enumerated() where index != preferredFileIndex {
            if playIdle(in: row, volume: volume) {
                return
            }
        }

        for (index, _) in voicesByFile.enumerated() where index != preferredFileIndex {
            if roundRobinInFile(index, volume: volume) {
                return
            }
        }

        if playIdle(in: spilloverVoices, volume: volume) {
            return
        }

        if !allVoices.isEmpty {
            let voice = allVoices[globalRoundRobin % allVoices.count]
            globalRoundRobin &+= 1
            fire(voice.player, volume: volume)
        }
    }

    @discardableResult
    private static func playIdle(in row: [ClickVoice], volume: Float) -> Bool {
        guard let voice = row.first(where: { !$0.player.isPlaying }) else { return false }
        fire(voice.player, volume: volume)
        return true
    }

    @discardableResult
    private static func roundRobinInFile(_ fileIndex: Int, volume: Float) -> Bool {
        let row = voicesByFile[fileIndex]
        guard !row.isEmpty else { return false }
        let slot = roundRobinByFile[fileIndex] % row.count
        roundRobinByFile[fileIndex] &+= 1
        fire(row[slot].player, volume: volume)
        return true
    }

    private static func playFromLegacyPool(volume: Float) {
        guard !legacyFallbackPlayers.isEmpty else { return }
        if let idle = legacyFallbackPlayers.first(where: { !$0.isPlaying }) {
            fire(idle, volume: volume)
            return
        }
        fire(legacyFallbackPlayers[globalRoundRobin % legacyFallbackPlayers.count], volume: volume)
        globalRoundRobin &+= 1
    }

    private static func fire(_ player: AVAudioPlayer, volume: Float) {
        player.volume = volume
        if player.isPlaying {
            player.stop()
        }
        player.currentTime = 0
        player.play()
    }

    private static func configureAudioSessionIfNeeded() {
        guard !didPrepareAudio else { return }
        AppAudioSession.configureForInAppSounds()
        didPrepareAudio = true
    }

    private static func loadPlayerPoolIfNeeded() {
        guard !didLoadPlayers else { return }
        didLoadPlayers = true

        var byFile: [[ClickVoice]] = []
        var loadedNames: [String] = []

        for basename in randomClickBasenames {
            guard let url = Bundle.main.url(forResource: basename, withExtension: clickFileExtension) else {
                #if DEBUG
                print("⚠️ [KeycapPressFeedback] bundle missing: \(basename).\(clickFileExtension)")
                #endif
                continue
            }
            var row: [ClickVoice] = []
            for _ in 0..<instancesPerClickFile {
                if let player = makePlayer(url: url) {
                    row.append(ClickVoice(basename: basename, player: player))
                }
            }
            if !row.isEmpty {
                byFile.append(row)
                loadedNames.append(basename)
            }
        }

        guard !byFile.isEmpty else {
            loadLegacyWavFallback()
            return
        }

        voicesByFile = byFile
        roundRobinByFile = Array(repeating: 0, count: byFile.count)

        var flat: [ClickVoice] = byFile.flatMap { $0 }
        spilloverVoices = []
        for index in 0..<spilloverVoiceCount {
            let basename = randomClickBasenames[index % randomClickBasenames.count]
            guard let url = Bundle.main.url(forResource: basename, withExtension: clickFileExtension),
                  let player = makePlayer(url: url) else { continue }
            let voice = ClickVoice(basename: basename, player: player)
            spilloverVoices.append(voice)
            flat.append(voice)
        }
        allVoices = flat

        #if DEBUG
        if loadedNames.count < clickFileCount {
            print("⚠️ [KeycapPressFeedback] click mp3 \(loadedNames.count)/\(clickFileCount)개 로드 — 누락 파일·타깃 확인")
        } else {
            print("✅ [KeycapPressFeedback] click1…click15 전부 로드 — \(allVoices.count) voices (+ spillover \(spilloverVoices.count))")
        }
        #endif
    }

    private static func loadLegacyWavFallback() {
        guard let url = Bundle.main.url(forResource: "KeycapClick", withExtension: "wav") else {
            #if DEBUG
            print("⚠️ [KeycapPressFeedback] 타건 파일 없음 (click1…15.mp3 또는 KeycapClick.wav)")
            #endif
            return
        }
        for _ in 0..<instancesPerClickFile {
            if let player = makePlayer(url: url) {
                legacyFallbackPlayers.append(player)
            }
        }
        #if DEBUG
        print("ℹ️ [KeycapPressFeedback] MP3 없음 — KeycapClick.wav 폴백")
        #endif
    }

    private static func makePlayer(url: URL) -> AVAudioPlayer? {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.enableRate = false
            player.prepareToPlay()
            return player
        } catch {
            #if DEBUG
            print("⚠️ [KeycapPressFeedback] load failed \(url.lastPathComponent): \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
