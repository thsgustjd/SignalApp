//
//  RoomInviteCodeCapsule.swift
//  SignalApp
//

import SwiftUI

/// 상단 방 코드 — 은은한 하늘색 캡슐 (시스템 툴바 크롬 없이 SwiftUI 단독 사용).
struct RoomInviteCodeCapsuleLabel: View {
    let code: String

    var body: some View {
        Text(code)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .tracking(0.2)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(CozyTheme.inviteCodeCapsuleText)
            .padding(.horizontal, 3)
            .padding(.vertical, 7)
            .background(CozyTheme.inviteCodeCapsuleFill, in: Capsule())
            .overlay(Capsule().strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth))
            .contentShape(Capsule())
    }
}
