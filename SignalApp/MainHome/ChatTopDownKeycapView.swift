//
//  ChatTopDownKeycapView.swift
//  SignalApp
//

import SwiftUI
import UIKit

// MARK: - Grid cell (고정 프ustum + 터치·사운드·눌림)

struct ChatKeycapSendButton: View {
    let symbolKey: String
    var onSend: () -> Void

    @State private var pressAmount: CGFloat = 0
    @State private var didTriggerHaptic = false

    private let hitShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        Color.white.opacity(0.001)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background {
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    KeycapPhysicalAssembly(
                        side: side,
                        symbolKey: symbolKey,
                        pressAmount: pressAmount
                    )
                }
            }
            .contentShape(hitShape)
            .highPriorityGesture(pressGesture)
            .animation(nil, value: pressAmount)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(AppGroupStorage.keycapSymbolPresentation(for: symbolKey).emoji)
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { _ in
                if pressAmount != 1 {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        pressAmount = 1
                    }
                }
                if !didTriggerHaptic {
                    didTriggerHaptic = true
                    KeycapPressFeedback.playPress()
                }
            }
            .onEnded { _ in
                didTriggerHaptic = false
                withAnimation(KeycapPressMotion.releaseUp) {
                    pressAmount = 0
                }
                onSend()
            }
    }
}

private enum KeycapPressMotion {
    /// 손을 뗄 때만 스프링 — 아래로 눌릴 때는 제스처에서 애니메이션 없이 즉시 1.
    static let releaseUp: Animation = .spring(response: 0.11, dampingFraction: 0.68, blendDuration: 0)
}


private struct KeycapPhysicalAssembly: View {
    let side: CGFloat
    let symbolKey: String
    let pressAmount: CGFloat

    private static let assemblyScale: CGFloat = 1.36
    private static let capAndPlatformScale: CGFloat = 0.9

    var body: some View {
        ZStack {
            KeycapFrustumKeycap(
                side: side,
                symbolKey: symbolKey,
                pressAmount: pressAmount
            )
            .offset(y: side * 0.010)
            .scaleEffect(Self.capAndPlatformScale)
        }
        .scaleEffect(Self.assemblyScale)
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }
}

private enum KeycapPhotoPalette {
    static let top = Color(red: 0.52, green: 0.80, blue: 0.90).opacity(0.48)
    static let topShine = Color(red: 0.90, green: 0.97, blue: 1.0).opacity(0.72)
    static let wallShadow = Color(red: 0.38, green: 0.64, blue: 0.76).opacity(0.62)
    static let wallMid = Color(red: 0.48, green: 0.74, blue: 0.86).opacity(0.52)
    static let wallLight = Color(red: 0.66, green: 0.88, blue: 0.94).opacity(0.62)
    static let skirt = Color(red: 0.46, green: 0.72, blue: 0.84).opacity(0.50)
    static let switchGlass = Color.white.opacity(0.42)
    static let switchGlassDeep = Color(red: 0.88, green: 0.92, blue: 0.95).opacity(0.55)
    static let switchEdge = Color(white: 0.72).opacity(0.85)
    static let stem = Color.white.opacity(0.95)
    static let edgeDark = Color(red: 0.38, green: 0.58, blue: 0.68).opacity(0.62)
    static let edgeMid = Color(red: 0.45, green: 0.65, blue: 0.76).opacity(0.55)
    static let plasticSpecular = Color.white.opacity(0.38)
    static let plasticSheen = Color.white.opacity(0.12)
}

private struct KeycapPerspectiveQuad {
    let tl: CGPoint
    let tr: CGPoint
    let br: CGPoint
    let bl: CGPoint
}

private enum KeycapPlatformMetrics {
    private static let legacyKeycapOuterHalf: CGFloat = 0.252
    private static let enlargedKeycapOuterHalf: CGFloat = 0.322

    static var keycapIncreaseAmount: CGFloat {
        enlargedKeycapOuterHalf / legacyKeycapOuterHalf - 1
    }

    static var platformLinearScale: CGFloat {
        1 + keycapIncreaseAmount * 0.7
    }

    static var platformTopHalf: CGFloat { legacyPlatformTopHalf * platformLinearScale }
    static var platformBottomHalf: CGFloat { legacyPlatformBottomHalf * platformLinearScale }
    static var platformTopDepth: CGFloat { legacyPlatformTopDepth * platformLinearScale }
    static var platformBottomDepth: CGFloat { legacyPlatformBottomDepth * platformLinearScale }
    static var platformVerticalSpan: CGFloat { legacyPlatformVerticalSpan * platformLinearScale }

    private static let legacyPlatformTopHalf: CGFloat = 0.252 * 0.92
    private static let legacyPlatformBottomHalf: CGFloat = 0.252 * 1.02
    private static let legacyPlatformTopDepth: CGFloat = 0.024
    private static let legacyPlatformBottomDepth: CGFloat = 0.030
    private static let legacyPlatformVerticalSpan: CGFloat = 0.096
}

private struct KeycapFrustumKeycap: View {
    let side: CGFloat
    let symbolKey: String
    let pressAmount: CGFloat

    var body: some View {
        let cx = side * 0.5
        let platformScale = KeycapPlatformMetrics.platformLinearScale

        let platformTopHalf = side * KeycapPlatformMetrics.platformTopHalf
        let platformBottomHalf = side * KeycapPlatformMetrics.platformBottomHalf

        let keycapInnerHalf = side * 0.200
        let keycapOuterHalf = side * 0.322

        let switchTopY = side * 0.595
        let switchBottomY = switchTopY + side * KeycapPlatformMetrics.platformVerticalSpan
        let stemRestGap = side * 0.112
        let outerCenterY = switchTopY - stemRestGap
        let innerCenterY = outerCenterY - side * 0.122

        let switchTop = perspectivePlatformSquare(
            cx: cx,
            cy: switchTopY,
            half: platformTopHalf,
            depth: side * KeycapPlatformMetrics.platformTopDepth
        )
        let switchBottom = perspectivePlatformSquare(
            cx: cx,
            cy: switchBottomY,
            half: platformBottomHalf,
            depth: side * KeycapPlatformMetrics.platformBottomDepth
        )

        let inner = perspectiveKeycapSquare(cx: cx, cy: innerCenterY, half: keycapInnerHalf, depth: side * 0.034)
        let outer = perspectiveKeycapSquare(cx: cx, cy: outerCenterY, half: keycapOuterHalf, depth: side * 0.048)

        let capPressTravel = side * 0.102 * pressAmount

        let emoji = AppGroupStorage.keycapSymbolPresentation(for: symbolKey).emoji

        ZStack {
            KeycapSwitchHousing(
                top: switchTop,
                bottom: switchBottom,
                side: side,
                detailScale: platformScale
            )

            ZStack {
                KeycapFrustumWall(a: inner.bl, b: inner.br, c: outer.br, d: outer.bl, light: KeycapPhotoPalette.wallShadow, dark: KeycapPhotoPalette.wallMid.opacity(0.92))
                KeycapFrustumWall(a: inner.br, b: inner.tr, c: outer.tr, d: outer.br, light: KeycapPhotoPalette.wallMid, dark: KeycapPhotoPalette.wallShadow)
                KeycapFrustumWall(a: inner.tl, b: inner.tr, c: outer.tr, d: outer.tl, light: KeycapPhotoPalette.wallLight, dark: KeycapPhotoPalette.wallMid)
                KeycapFrustumWall(a: inner.bl, b: inner.tl, c: outer.tl, d: outer.bl, light: KeycapPhotoPalette.wallMid, dark: KeycapPhotoPalette.wallShadow.opacity(0.95))

                KeycapFrustumFace(corners: [outer.tl, outer.tr, outer.br, outer.bl], fill: KeycapPhotoPalette.skirt)

                KeycapFrustumFace(
                    corners: [inner.tl, inner.tr, inner.br, inner.bl],
                    fill: KeycapPhotoPalette.top,
                    gradient: KeycapPhotoPalette.topShine
                )
                .overlay {
                    KeycapPlasticSpecularLayer(corners: inner)
                }

                KeycapFrustumOutline(corners: [outer.tl, outer.tr, outer.br, outer.bl], color: KeycapPhotoPalette.edgeMid.opacity(0.92), lineWidth: 1.15)
                KeycapFrustumOutline(corners: [inner.tl, inner.tr, inner.br, inner.bl], color: Color.white.opacity(0.84), lineWidth: 1.25)
                KeycapFrustumOutline(corners: [inner.tl, inner.tr, inner.br, inner.bl], color: KeycapPhotoPalette.edgeDark, lineWidth: 1.45)

                KeycapFrustumEdge(from: inner.tl, to: outer.tl, opacity: 0.92, color: KeycapPhotoPalette.edgeDark, lineWidth: 1.55)
                KeycapFrustumEdge(from: inner.tr, to: outer.tr, opacity: 0.92, color: KeycapPhotoPalette.edgeDark, lineWidth: 1.55)
                KeycapFrustumEdge(from: inner.br, to: outer.br, opacity: 0.82, color: KeycapPhotoPalette.edgeMid, lineWidth: 1.35)
                KeycapFrustumEdge(from: inner.bl, to: outer.bl, opacity: 0.82, color: KeycapPhotoPalette.edgeMid, lineWidth: 1.35)

                KeycapEmojiOnTopFace(emoji: emoji, corners: inner, fontScale: 0.92)
            }
            .offset(y: capPressTravel)
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }

    private func perspectivePlatformSquare(cx: CGFloat, cy: CGFloat, half: CGFloat, depth: CGFloat) -> KeycapPerspectiveQuad {
        let topInset = depth * 0.32
        let sideInset = depth * 0.26
        let bottomLift = depth * 0.12
        let cornerSoft = depth * 0.14
        return KeycapPerspectiveQuad(
            tl: CGPoint(x: cx - half + depth * 0.95 + cornerSoft * 0.25, y: cy - half + topInset),
            tr: CGPoint(x: cx + half - depth * 0.95 - cornerSoft * 0.25, y: cy - half + topInset),
            br: CGPoint(x: cx + half - sideInset * 0.92, y: cy + half - bottomLift),
            bl: CGPoint(x: cx - half + sideInset * 0.92, y: cy + half - bottomLift)
        )
    }

    private func perspectiveKeycapSquare(cx: CGFloat, cy: CGFloat, half: CGFloat, depth: CGFloat) -> KeycapPerspectiveQuad {
        let topInset = depth * 0.38
        let sideInset = depth * 0.24
        let bottomLift = depth * 0.16
        return KeycapPerspectiveQuad(
            tl: CGPoint(x: cx - half + depth * 1.08, y: cy - half + topInset),
            tr: CGPoint(x: cx + half - depth * 1.08, y: cy - half + topInset),
            br: CGPoint(x: cx + half - sideInset, y: cy + half - bottomLift),
            bl: CGPoint(x: cx - half + sideInset, y: cy + half - bottomLift)
        )
    }
}

private struct KeycapSwitchHousing: View {
    let top: KeycapPerspectiveQuad
    let bottom: KeycapPerspectiveQuad
    let side: CGFloat
    var detailScale: CGFloat = 1

    var body: some View {
        let s = detailScale
        ZStack {
            KeycapFrustumWall(a: top.bl, b: top.br, c: bottom.br, d: bottom.bl, light: KeycapPhotoPalette.switchGlassDeep, dark: KeycapPhotoPalette.switchGlass)
            KeycapFrustumWall(a: top.br, b: top.tr, c: bottom.tr, d: bottom.br, light: KeycapPhotoPalette.switchGlass, dark: KeycapPhotoPalette.switchGlassDeep)
            KeycapFrustumWall(a: top.tl, b: top.tr, c: bottom.tr, d: bottom.tl, light: Color.white.opacity(0.58), dark: KeycapPhotoPalette.switchGlass)

            KeycapFrustumFace(corners: [bottom.tl, bottom.tr, bottom.br, bottom.bl], fill: KeycapPhotoPalette.switchGlassDeep)
            KeycapFrustumOutline(corners: [bottom.tl, bottom.tr, bottom.br, bottom.bl], color: KeycapPhotoPalette.switchEdge, lineWidth: 0.7 * s)
            KeycapFrustumOutline(corners: [top.tl, top.tr, top.br, top.bl], color: KeycapPhotoPalette.switchEdge.opacity(0.78), lineWidth: 0.65 * s)

            RoundedRectangle(cornerRadius: side * 0.018 * s, style: .continuous)
                .fill(KeycapPhotoPalette.stem)
                .frame(width: side * 0.11 * s, height: side * 0.07 * s)
                .position(
                    x: (top.tl.x + top.tr.x + top.br.x + top.bl.x) / 4,
                    y: (top.tl.y + top.tr.y + top.br.y + top.bl.y) / 4 + side * 0.02 * s
                )

            RoundedRectangle(cornerRadius: 1.2 * s, style: .continuous)
                .fill(Color(white: 0.78).opacity(0.65))
                .frame(width: side * 0.04 * s, height: side * 0.025 * s)
                .position(
                    x: bottom.br.x - side * 0.06 * s,
                    y: bottom.br.y - side * 0.04 * s
                )
        }
    }
}

private struct KeycapEmojiOnTopFace: View {
    let emoji: String
    let corners: KeycapPerspectiveQuad
    var fontScale: CGFloat = 1

    var body: some View {
        let center = CGPoint(
            x: (corners.tl.x + corners.tr.x + corners.br.x + corners.bl.x) / 4,
            y: (corners.tl.y + corners.tr.y + corners.br.y + corners.bl.y) / 4
        )
        let topEdge = hypot(corners.tr.x - corners.tl.x, corners.tr.y - corners.tl.y)
        let leftEdge = hypot(corners.bl.x - corners.tl.x, corners.bl.y - corners.tl.y)
        let fontSize = min(topEdge, leftEdge) * 0.58 * fontScale
        let angle = Angle(radians: atan2(corners.tr.y - corners.tl.y, corners.tr.x - corners.tl.x))

        Text(emoji)
            .font(.system(size: fontSize))
            .rotationEffect(angle)
            .offset(y: -fontSize * 0.06)
            .position(center)
            .allowsHitTesting(false)
    }
}

private struct KeycapPlasticSpecularLayer: View {
    let corners: KeycapPerspectiveQuad

    var body: some View {
        Path { path in
            path.move(to: corners.tl)
            path.addLine(to: corners.tr)
            path.addLine(to: corners.br)
            path.addLine(to: corners.bl)
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    KeycapPhotoPalette.plasticSpecular,
                    KeycapPhotoPalette.plasticSheen,
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .blendMode(.plusLighter)
    }
}

private struct KeycapFrustumWall: View {
    let a: CGPoint
    let b: CGPoint
    let c: CGPoint
    let d: CGPoint
    let light: Color
    let dark: Color

    var body: some View {
        Path { path in
            path.move(to: a)
            path.addLine(to: b)
            path.addLine(to: c)
            path.addLine(to: d)
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [light, dark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct KeycapFrustumFace: View {
    let corners: [CGPoint]
    let fill: Color
    var gradient: Color?

    var body: some View {
        Path { path in
            guard let first = corners.first else { return }
            path.move(to: first)
            for point in corners.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [gradient ?? fill, fill],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct KeycapFrustumOutline: View {
    let corners: [CGPoint]
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        Path { path in
            guard let first = corners.first else { return }
            path.move(to: first)
            for point in corners.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
        .stroke(color, lineWidth: lineWidth)
    }
}

private struct KeycapFrustumEdge: View {
    let from: CGPoint
    let to: CGPoint
    var opacity: Double = 0.5
    var color: Color = Color(white: 0.55)
    var lineWidth: CGFloat = 1.1

    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(color.opacity(opacity), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
}

struct ChatTopDownKeycapView: View {
    let symbolKey: String
    let capTint: Color

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            KeycapPhysicalAssembly(side: side, symbolKey: symbolKey, pressAmount: 0)
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(false)
    }
}

struct ChatKeycapPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .animation(
                configuration.isPressed ? nil : KeycapPressMotion.releaseUp,
                value: configuration.isPressed
            )
    }
}
