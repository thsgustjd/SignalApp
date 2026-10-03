//
//  SignalWidgetBundle.swift
//  SignalWidget
//

import SwiftUI
import WidgetKit

@main
struct SignalWidgetBundle: WidgetBundle {
    var body: some Widget {
        HeartKeycapWidget()
        PleadingKeycapWidget()
        TongueKeycapWidget()
        QuestionKeycapWidget()
        AngryKeycapWidget()
        SleepKeycapWidget()
        GrinKeycapWidget()
        CloverKeycapWidget()
        PencilKeycapWidget()
        DocKeycapWidget()
        TiredKeycapWidget()
        HungryKeycapWidget()
        ColdKeycapWidget()
        HotKeycapWidget()
        PlayKeycapWidget()
        DNDKeycapWidget()
        EmergencyKeycapWidget()
    }
}

struct HeartKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "HeartKeycapWidget",
            displayName: "사랑해 키캡",
            description: "탭해 사랑해 넛지를 보냅니다.",
            systemName: "heart.fill",
            nudgeType: "heart"
        )
    }
}

struct PleadingKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "PleadingKeycapWidget",
            displayName: "보고싶어 키캡",
            description: "탭해 보고싶어 넛지를 보냅니다.",
            systemName: "face.smiling",
            nudgeType: "pleading"
        )
    }
}

struct TongueKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "TongueKeycapWidget",
            displayName: "메롱 키캡",
            description: "탭해 메롱 넛지를 보냅니다.",
            systemName: "face.smiling",
            nudgeType: "tongue"
        )
    }
}

struct QuestionKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "QuestionKeycapWidget",
            displayName: "뭐해 키캡",
            description: "탭해 뭐해? 넛지를 보냅니다.",
            systemName: "questionmark",
            nudgeType: "question"
        )
    }
}

struct AngryKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "AngryKeycapWidget",
            displayName: "그만해라 키캡",
            description: "탭해 그만해라 넛지를 보냅니다.",
            systemName: "exclamationmark.bubble.fill",
            nudgeType: "angry"
        )
    }
}

struct SleepKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "SleepKeycapWidget",
            displayName: "잘자 키캡",
            description: "탭해 잘자 넛지를 보냅니다.",
            systemName: "moon.zzz.fill",
            nudgeType: "sleep"
        )
    }
}

struct GrinKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "GrinKeycapWidget",
            displayName: "굿모닝 키캡",
            description: "탭해 굿모닝! 넛지를 보냅니다.",
            systemName: "sun.max.fill",
            nudgeType: "grin"
        )
    }
}

struct CloverKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "CloverKeycapWidget",
            displayName: "흥! 키캡",
            description: "탭해 흥! 넛지를 보냅니다.",
            systemName: "leaf.fill",
            nudgeType: "clover"
        )
    }
}

struct PencilKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "PencilKeycapWidget",
            displayName: "연락 봐줘",
            description: "탭해 연락 봐줘 넛지를 보냅니다.",
            systemName: "message.fill",
            nudgeType: "pencil"
        )
    }
}

struct DocKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "DocKeycapWidget",
            displayName: "전화 해줘",
            description: "탭해 전화 해줘 넛지를 보냅니다.",
            systemName: "phone.fill",
            nudgeType: "doc"
        )
    }
}

struct TiredKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "TiredKeycapWidget",
            displayName: "피곤해",
            description: "탭해 피곤해 넛지를 보냅니다.",
            systemName: "bed.double.fill",
            nudgeType: "tired"
        )
    }
}

struct HungryKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "HungryKeycapWidget",
            displayName: "배고파 키캡",
            description: "탭해 배고파 넛지를 보냅니다.",
            systemName: "fork.knife",
            nudgeType: "hungry"
        )
    }
}

struct ColdKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "ColdKeycapWidget",
            displayName: "심심해 키캡",
            description: "탭해 심심해 넛지를 보냅니다.",
            systemName: "ellipsis.bubble",
            nudgeType: "cold"
        )
    }
}

struct HotKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "HotKeycapWidget",
            displayName: "퇴근 키캡",
            description: "탭해 퇴근 넛지를 보냅니다.",
            systemName: "figure.wave",
            nudgeType: "hot"
        )
    }
}

#Preview(as: .accessoryCircular) {
    HeartKeycapWidget()
} timeline: {
    KeycapEntry(date: .now, isLinked: true)
}
