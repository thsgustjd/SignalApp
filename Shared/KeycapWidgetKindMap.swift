//
//  KeycapWidgetKindMap.swift
//  SignalApp / SignalWidget (Shared)
//

import Foundation

/// `SignalWidget`의 `StaticConfiguration.kind` ↔ 넛지 타입 매핑.
enum KeycapWidgetKindMap {
    static let dndWidgetKind = "DNDKeycapWidget"
    static let emergencyWidgetKind = "EmergencyKeycapWidget"

    static let kindToNudgeType: [String: String] = [
        "HeartKeycapWidget": "heart",
        "PleadingKeycapWidget": "pleading",
        "TongueKeycapWidget": "tongue",
        "QuestionKeycapWidget": "question",
        "AngryKeycapWidget": "angry",
        "SleepKeycapWidget": "sleep",
        "GrinKeycapWidget": "grin",
        "CloverKeycapWidget": "clover",
        "PencilKeycapWidget": "pencil",
        "DocKeycapWidget": "doc",
        "TiredKeycapWidget": "tired",
        "HungryKeycapWidget": "hungry",
        "ColdKeycapWidget": "cold",
        "HotKeycapWidget": "hot",
        "PlayKeycapWidget": "play",
    ]

    static func nudgeType(forWidgetKind kind: String) -> String? {
        kindToNudgeType[kind]
    }
}
