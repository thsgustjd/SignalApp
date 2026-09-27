//
//  CozyTheme.swift
//  SignalApp
//

import SwiftUI

enum CozyTheme {
    static let pink = Color(red: 0.95, green: 0.55, blue: 0.72)
    static let lavender = Color(red: 0.72, green: 0.58, blue: 0.92)
    static let sand = Color(red: 0.94, green: 0.88, blue: 0.80)

    static let background = Color(red: 0.99, green: 0.94, blue: 0.96)
    static let card = Color.white.opacity(0.78)
    static let accent = lavender
    static let textPrimary = Color(red: 0.28, green: 0.18, blue: 0.32)
    static let textSecondary = Color(red: 0.42, green: 0.34, blue: 0.46)

    static var roomBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.93, blue: 0.96),
                Color(red: 0.96, green: 0.92, blue: 0.99),
                sand,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let cornerRadius: CGFloat = 20
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)
}
