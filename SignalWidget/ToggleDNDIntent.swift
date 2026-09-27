//
//  ToggleDNDIntent.swift
//  SignalWidget
//

import AppIntents
import AudioToolbox
import WidgetKit

struct ToggleDNDIntent: AppIntent {
    static var title: LocalizedStringResource = "방해금지 토글"
    static var description = IntentDescription("시그널 수신 알림을 켜거나 끕니다.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    func perform() async throws -> some IntentResult {
        AppGroupStorage.toggleSignalDNDActive()
        triggerKeycapHaptic()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
