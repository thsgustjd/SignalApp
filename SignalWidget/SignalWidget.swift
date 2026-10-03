//
//  SignalWidget.swift
//  SignalWidget
//

import AppIntents
import SwiftUI
import WidgetKit

struct KeycapEntry: TimelineEntry {
    let date: Date
    let isLinked: Bool
}

struct KeycapTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> KeycapEntry {
        KeycapEntry(date: .now, isLinked: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (KeycapEntry) -> Void) {
        completion(KeycapEntry(date: .now, isLinked: AppGroupStorage.isWidgetSendConfigured))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KeycapEntry>) -> Void) {
        let entry = KeycapEntry(date: .now, isLinked: AppGroupStorage.isWidgetSendConfigured)
        let policy: TimelineReloadPolicy = entry.isLinked
            ? .never
            : .after(Date().addingTimeInterval(15))
        completion(Timeline(entries: [entry], policy: policy))
    }
}

struct KeycapWidgetEntryView: View {
    var entry: KeycapEntry
    let systemName: String
    let nudgeType: String

    var body: some View {
        Button(intent: SendHeartIntent(nudgeType: nudgeType)) {
            TopDownKeycapView(systemName: systemName, nudgeType: nudgeType)
        }
        .buttonStyle(KeycapPressButtonStyle())
        .opacity(entry.isLinked ? 1 : 0.42)
    }
}

/// 탑뷰 3D 기계식 키캡 (원형 잠금화면 슬롯 안).
struct TopDownKeycapView: View {
    let systemName: String
    let nudgeType: String

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let plateScale: CGFloat = 0.68
            let innerSide = side * plateScale
            let innerRadius: CGFloat = 6
            let symbolSize = innerSide * 0.42

            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.42),
                                Color(white: 0.20),
                                Color(white: 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.72),
                                        Color.black.opacity(0.42)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    )
                    .shadow(color: .black.opacity(0.55), radius: 3.5, x: 0, y: 2.5)

                KeycapChamferRidges(
                    side: side,
                    innerSide: innerSide,
                    outerRadius: 11,
                    innerRadius: innerRadius
                )

                RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.26),
                                Color(white: 0.15),
                                Color(white: 0.09)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: innerSide, height: innerSide)
                    .overlay(
                        RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.55), lineWidth: 1.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.38), radius: 2, x: 1.5, y: 1.5)

                keycapSymbolContent(symbolSize: symbolSize)
            }
            .frame(width: side, height: side)
        }
        .accessibilityLabel(nudgeType)
    }

    @ViewBuilder
    private func keycapSymbolContent(symbolSize: CGFloat) -> some View {
        if let emoji = AppGroupStorage.keycapEmoji(for: nudgeType) {
            Text(emoji)
                .font(.system(size: symbolSize * 0.88))
                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 1)
        } else {
            Image(systemName: systemName)
                .font(.system(size: symbolSize * 0.95, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.35), radius: 0.5, x: 0, y: 1)
        }
    }
}

/// 바깥 베이스 ↔ 안쪽 상판 사이 4면 대각선 모따기(Chamfer) 릿지.
private struct KeycapChamferRidges: View {
    let side: CGFloat
    let innerSide: CGFloat
    let outerRadius: CGFloat
    let innerRadius: CGFloat
    var brightRidgeOpacity: CGFloat = 0.7
    var dimRidgeOpacity: CGFloat = 0.4

    /// 라운드 코너 중심에서 45° 방향(꼭짓점 쪽) 아크 위 점 — 외·내부 대응 꼭짓점 연결용.
    private func cornerArcVertex(
        corner: KeycapCorner,
        side: CGFloat,
        pad: CGFloat,
        outerRadius: CGFloat,
        innerRadius: CGFloat,
        outer: Bool
    ) -> CGPoint {
        let radius = outer ? outerRadius : innerRadius
        let inset = radius * (1 - CGFloat(2).squareRoot() / 2)
        let innerOrigin = pad

        switch corner {
        case .topLeading:
            if outer {
                return CGPoint(x: inset, y: inset)
            }
            return CGPoint(x: innerOrigin + inset, y: innerOrigin + inset)
        case .topTrailing:
            if outer {
                return CGPoint(x: side - inset, y: inset)
            }
            return CGPoint(x: innerOrigin + innerSide - inset, y: innerOrigin + inset)
        case .bottomLeading:
            if outer {
                return CGPoint(x: inset, y: side - inset)
            }
            return CGPoint(x: innerOrigin + inset, y: innerOrigin + innerSide - inset)
        case .bottomTrailing:
            if outer {
                return CGPoint(x: side - inset, y: side - inset)
            }
            return CGPoint(x: innerOrigin + innerSide - inset, y: innerOrigin + innerSide - inset)
        }
    }

    var body: some View {
        GeometryReader { _ in
            let pad = (side - innerSide) / 2

            ZStack {
                chamferSegment(
                    corner: .topLeading,
                    pad: pad,
                    color: Color.white.opacity(brightRidgeOpacity),
                    lineWidth: 1.2
                )
                chamferSegment(
                    corner: .topTrailing,
                    pad: pad,
                    color: Color.white.opacity(brightRidgeOpacity),
                    lineWidth: 1.2
                )
                chamferSegment(
                    corner: .bottomLeading,
                    pad: pad,
                    color: Color.white.opacity(dimRidgeOpacity),
                    lineWidth: 1.2
                )
                chamferSegment(
                    corner: .bottomTrailing,
                    pad: pad,
                    color: Color.white.opacity(dimRidgeOpacity),
                    lineWidth: 1.2
                )
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }

    private func chamferSegment(
        corner: KeycapCorner,
        pad: CGFloat,
        color: Color,
        lineWidth: CGFloat
    ) -> some View {
        let start = cornerArcVertex(
            corner: corner,
            side: side,
            pad: pad,
            outerRadius: outerRadius,
            innerRadius: innerRadius,
            outer: true
        )
        let end = cornerArcVertex(
            corner: corner,
            side: side,
            pad: pad,
            outerRadius: outerRadius,
            innerRadius: innerRadius,
            outer: false
        )

        return Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
}

private enum KeycapCorner {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
}

struct KeycapPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

enum KeycapWidgetFactory {
    static func configuration(
        kind: String,
        displayName: String,
        description: String,
        systemName: String,
        nudgeType: String
    ) -> some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KeycapTimelineProvider()) { entry in
            KeycapWidgetEntryView(entry: entry, systemName: systemName, nudgeType: nudgeType)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(displayName)
        .description(description)
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - 놀자 😆 키캡

struct PlayKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        KeycapWidgetFactory.configuration(
            kind: "PlayKeycapWidget",
            displayName: "놀자 키캡",
            description: "탭해 놀자 넛지를 보냅니다.",
            systemName: "face.smiling",
            nudgeType: "play"
        )
    }
}

// MARK: - 방해금지 🚫 락 키캡

struct DNDEntry: TimelineEntry {
    let date: Date
    let isDNDActive: Bool
}

struct DNDTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DNDEntry {
        DNDEntry(date: .now, isDNDActive: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (DNDEntry) -> Void) {
        completion(DNDEntry(date: .now, isDNDActive: AppGroupStorage.isSignalDNDActive))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DNDEntry>) -> Void) {
        let entry = DNDEntry(date: .now, isDNDActive: AppGroupStorage.isSignalDNDActive)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct DNDKeycapWidgetEntryView: View {
    var entry: DNDEntry

    var body: some View {
        Button(intent: ToggleDNDIntent()) {
            DNDTopDownKeycapView(isDNDActive: entry.isDNDActive)
        }
        .buttonStyle(KeycapPressButtonStyle())
    }
}

/// 🚫 방해금지 — 토글 시 눌린(음각) 3D 상태 연출.
struct DNDTopDownKeycapView: View {
    let isDNDActive: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let plateScale: CGFloat = isDNDActive ? 0.52 : 0.68
            let innerSide = side * plateScale
            let innerRadius: CGFloat = 6
            let plateOffset = isDNDActive ? CGSize(width: 1.5, height: 1.5) : .zero

            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(outerSlopeGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isDNDActive ? 0.28 : 0.72),
                                        Color.black.opacity(isDNDActive ? 0.65 : 0.42)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    )
                    .overlay {
                        if isDNDActive {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.black.opacity(0.72),
                                            Color.black.opacity(0.35),
                                            Color.clear
                                        ],
                                        center: .topLeading,
                                        startRadius: 0,
                                        endRadius: side * 0.72
                                    )
                                )
                                .allowsHitTesting(false)
                        }
                    }
                    .shadow(
                        color: .black.opacity(isDNDActive ? 0.78 : 0.55),
                        radius: isDNDActive ? 2 : 3.5,
                        x: 0,
                        y: isDNDActive ? 1 : 2.5
                    )

                KeycapChamferRidges(
                    side: side,
                    innerSide: innerSide,
                    outerRadius: 11,
                    innerRadius: innerRadius,
                    brightRidgeOpacity: isDNDActive ? 0.8 : 0.7,
                    dimRidgeOpacity: isDNDActive ? 0.8 : 0.4
                )

                innerPlate(side: innerSide, innerRadius: innerRadius)
                    .offset(plateOffset)

                dndSymbol(innerSide: innerSide)
                    .offset(plateOffset)
            }
            .frame(width: side, height: side)
        }
        .accessibilityLabel(isDNDActive ? "방해금지 켜짐" : "방해금지 꺼짐")
    }

    private var outerSlopeGradient: LinearGradient {
        if isDNDActive {
            return LinearGradient(
                colors: [
                    Color(white: 0.05),
                    Color(white: 0.12),
                    Color(white: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(white: 0.42),
                Color(white: 0.20),
                Color(white: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func innerPlate(side innerSide: CGFloat, innerRadius: CGFloat) -> some View {
        if isDNDActive {
            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                .fill(Color(white: 0.07))
                .frame(width: innerSide, height: innerSide)
                .overlay(
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .strokeBorder(Color(white: 0.02), lineWidth: 1.2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.55), lineWidth: 1.5)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .stroke(Color.black.opacity(0.55), lineWidth: 5)
                        .blur(radius: 3.5)
                        .padding(3)
                        .allowsHitTesting(false)
                }
        } else {
            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.28), Color(white: 0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: innerSide, height: innerSide)
                .overlay(
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.55), lineWidth: 1.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.38), radius: 2, x: 1.5, y: 1.5)
        }
    }

    @ViewBuilder
    private func dndSymbol(innerSide: CGFloat) -> some View {
        if isDNDActive {
            Text("🚫")
                .font(.system(size: innerSide * 0.38))
                .opacity(0.4)
                .blur(radius: 0.2)
        } else {
            Text("🚫")
                .font(.system(size: innerSide * 0.45))
                .opacity(1.0)
                .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 1)
        }
    }
}

struct DNDKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DNDKeycapWidget", provider: DNDTimelineProvider()) { entry in
            DNDKeycapWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("방해금지 키캡")
        .description("탭해 수신 알림·진동을 켜거나 끕니다.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - 🚨 비상 키캡

struct EmergencyEntry: TimelineEntry {
    let date: Date
    let phase: AppGroupStorage.EmergencyInteractionPhase
    let isLinked: Bool
}

struct EmergencyTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> EmergencyEntry {
        EmergencyEntry(date: .now, phase: .counting(current: 0, required: 5), isLinked: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (EmergencyEntry) -> Void) {
        completion(
            EmergencyEntry(
                date: .now,
                phase: AppGroupStorage.emergencyInteractionPhase(),
                isLinked: AppGroupStorage.isWidgetSendConfigured
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EmergencyEntry>) -> Void) {
        let now = Date()
        let phase = AppGroupStorage.emergencyInteractionPhase(now: now)
        let entry = EmergencyEntry(
            date: now,
            phase: phase,
            isLinked: AppGroupStorage.isWidgetSendConfigured
        )
        let policy: TimelineReloadPolicy = {
            if let reloadAt = AppGroupStorage.emergencyWidgetNextReloadDate(now: now) {
                return .after(reloadAt)
            }
            switch phase {
            case .armedWaitingLongPress:
                return .after(now.addingTimeInterval(1))
            case .cooldown:
                return .after(now.addingTimeInterval(15))
            default:
                return entry.isLinked ? .never : .after(now.addingTimeInterval(15))
            }
        }()
        completion(Timeline(entries: [entry], policy: policy))
    }
}

struct EmergencyKeycapWidgetEntryView: View {
    var entry: EmergencyEntry

    var body: some View {
        Button(intent: EmergencyKeycapPressIntent()) {
            EmergencyTopDownKeycapView(phase: entry.phase)
        }
        .buttonStyle(KeycapPressButtonStyle())
        .opacity(entry.isLinked ? 1 : 0.42)
    }
}

struct EmergencyTopDownKeycapView: View {
    let phase: AppGroupStorage.EmergencyInteractionPhase

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let plateScale: CGFloat = 0.68
            let innerSide = side * plateScale
            let innerRadius: CGFloat = 6
            let symbolSize = innerSide * 0.42

            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.42),
                                Color(white: 0.20),
                                Color(white: 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.72),
                                        Color.black.opacity(0.42)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.4
                            )
                    )
                    .shadow(color: .black.opacity(0.55), radius: 3.5, x: 0, y: 2.5)

                KeycapChamferRidges(
                    side: side,
                    innerSide: innerSide,
                    outerRadius: 11,
                    innerRadius: innerRadius
                )

                RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.26),
                                Color(white: 0.15),
                                Color(white: 0.09)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: innerSide, height: innerSide)
                    .overlay(
                        RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.55), lineWidth: 1.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.38), radius: 2, x: 1.5, y: 1.5)

                Text("🚨")
                    .font(.system(size: symbolSize * 0.88))
                    .shadow(color: .black.opacity(0.2), radius: 0.5, x: 0, y: 1)

                if let hint = hintText {
                    Text(hint)
                        .font(.system(size: innerSide * 0.18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .offset(y: innerSide * 0.38)
                        .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel("비상 키캡")
    }

    private var hintText: String? {
        switch phase {
        case .counting(let current, let required):
            return "\(current)/\(required)"
        case .armedWaitingLongPress:
            return "확인"
        case .cooldown:
            return nil
        }
    }
}

struct EmergencyKeycapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EmergencyKeycapWidget", provider: EmergencyTimelineProvider()) { entry in
            EmergencyKeycapWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("비상 키캡")
        .description("연결된 상대에게 우선 알림을 보냅니다. 119 등 공공 긴급전화가 아닙니다. 5회 연타 후 길게 눌러 전송.")
        .supportedFamilies([.accessoryCircular])
    }
}
