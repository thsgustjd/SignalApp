//
//  EmergencyKeycapIntent.swift
//  SignalWidget
//

import AppIntents
import WidgetKit

struct EmergencyKeycapPressIntent: AppIntent {
    static var title: LocalizedStringResource = "비상 키캡"
    static var description = IntentDescription("5회 연타 후 확인 눌림으로 비상 알림을 보냅니다.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        triggerKeycapHaptic()

        if case .armedWaitingLongPress = AppGroupStorage.emergencyInteractionPhase() {
            if AppGroupStorage.confirmEmergencyLongPress() {
                let result = await HeartWidgetService.sendEmergency()
                switch result {
                case .sent:
                    triggerEmergencySentConfirmationHaptic()
                    print("🚨 [EmergencyIntent] sent")
                case .cooldown(let remaining):
                    print("🚨 [EmergencyIntent] cooldown \(remaining)s")
                case .notConfigured:
                    print("🚨 [EmergencyIntent] not configured")
                case .failed(let message):
                    print("🚨 [EmergencyIntent] failed: \(message)")
                }
            }
        } else {
            _ = AppGroupStorage.recordEmergencyTap()
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "EmergencyKeycapWidget")
        return .result()
    }
}
