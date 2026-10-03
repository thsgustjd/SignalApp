//
//  SendHeartIntent.swift
//  SignalWidget
//

import AppIntents
import AudioToolbox

func triggerKeycapHaptic() {
    // 1519: 스위치 걸림 피드백 (Peek 햅틱)
    // 1520: 강한 피드백 (Pop 햅틱)
    AudioServicesPlaySystemSound(1519)
}

/// 비상 전송 성공 — 보낸 기기에서 확인 진동.
func triggerEmergencySentConfirmationHaptic() {
    AudioServicesPlaySystemSound(1520)
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
}

struct SendHeartIntent: AppIntent {
    static var title: LocalizedStringResource = "키캡 넛지 보내기"
    static var description = IntentDescription("키캡 탭으로 넛지를 보냅니다.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "넛지 타입")
    var nudgeType: String?

    init() {
        nudgeType = "heart"
    }

    init(nudgeType: String) {
        self.nudgeType = nudgeType
    }

    func perform() async throws -> some IntentResult {
        triggerKeycapHaptic()

        let type = nudgeType ?? "heart"

        Task.detached(priority: .userInitiated) {
            let result = await HeartWidgetService.sendHeart(symbolKey: type)
            switch result {
            case .sent:
                print("⌨️ [KeycapIntent] sent \(type)")
            case .cooldown:
                print("⌨️ [KeycapIntent] throttled (short)")
            case .notConfigured:
                print("⌨️ [KeycapIntent] App Group 미설정")
            case .failed(let message):
                print("⌨️ [KeycapIntent] failed: \(message)")
            }
        }

        return .result()
    }
}
