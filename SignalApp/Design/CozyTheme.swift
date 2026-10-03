//
//  CozyTheme.swift
//  SignalApp
//

import SwiftUI

enum CozyTheme {
    /// 밝은 하늘 하이라이트 (그라데이션·글로우)
    static let pink = Color(red: 0.58, green: 0.84, blue: 0.98)
    /// 메인 스카이 액센트
    static let lavender = Color(red: 0.48, green: 0.74, blue: 0.96)
    static let sand = Color(red: 0.90, green: 0.95, blue: 0.99)

    static let background = Color(red: 0.97, green: 0.99, blue: 1.0)
    /// 큰 카드·패널 (흰색으로 하늘 배경과 번갈아 구분)
    static let card = Color.white
    static let accent = lavender
    static let textPrimary = Color.black
    static let textSecondary = Color.black

    /// 강조 아이콘 (홈 키보드 등)
    static let deepBlue = Color(red: 0.05, green: 0.32, blue: 0.72)

    /// 작은 입력·뱃지 — `roomBackground`와 같은 하늘 톤
    static let panelInsetFill = Color(red: 0.92, green: 0.97, blue: 1.0)

    /// 상단 초대 코드 캡슐
    static let inviteCodeCapsuleFill = Color(red: 0.86, green: 0.94, blue: 0.99)
    static let inviteCodeCapsuleText = Color.black

    static var roomBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.99, blue: 1.0),
                Color(red: 0.92, green: 0.97, blue: 1.0),
                sand,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let cornerRadius: CGFloat = 20
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)

    /// 카드·입력·버블 등 UI 구분용 테두리
    static let uiBorder = Color.black
    static let uiBorderWidth: CGFloat = 1
}

extension View {
    func cozyUIBorderOverlay(
        cornerRadius: CGFloat,
        lineWidth: CGFloat = CozyTheme.uiBorderWidth
    ) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(CozyTheme.uiBorder, lineWidth: lineWidth)
        )
    }
}
