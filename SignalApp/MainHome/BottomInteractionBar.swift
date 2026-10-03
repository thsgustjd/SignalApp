//
//  BottomInteractionBar.swift
//  SignalApp
//

import SwiftUI
import UIKit

enum MainRoomTab: Equatable {
    case keycapSettings
    case keycaps
    case chatRoom
}

enum RoomTabBarLayout {
    static let barHeight: CGFloat = 56

    /// 스크롤 콘텐츠가 탭 바에 가리지 않도록 할 때 참고 (홈 인디케이터 + 바 높이).
    static var scrollClearance: CGFloat {
        barHeight + homeIndicatorFallback
    }

    static let homeIndicatorFallback: CGFloat = 34
}

private enum RoomTabBarStyle {
    static let barHeight = RoomTabBarLayout.barHeight

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [CozyTheme.pink, CozyTheme.lavender],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var barFillGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.94),
                Color(red: 0.97, green: 0.99, blue: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// 하단 3탭 — 키캡 셋팅 · 키캡 · 채팅방 (직사각형, 한 줄 균등 배치)
struct MainRoomTabBar: View {
    @Binding var selectedTab: MainRoomTab
    let isBusy: Bool

    var body: some View {
        let homeIndicatorInset = resolvedHomeIndicatorInset(0)

        VStack(spacing: 0) {
            Rectangle()
                .fill(CozyTheme.uiBorder)
                .frame(height: CozyTheme.uiBorderWidth)

            HStack(spacing: 0) {
                tabItem(
                    systemName: "slider.horizontal.3",
                    title: "키캡 셋팅",
                    tab: .keycapSettings
                )
                tabItem(
                    systemName: "square.grid.3x3.fill",
                    title: "키캡",
                    tab: .keycaps
                )
                tabItem(
                    assetName: BipbiCharacterAssets.tabIcon,
                    emojiFallback: "🐣",
                    title: "삐삐",
                    tab: .chatRoom
                )
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .padding(.bottom, tabContentBottomPadding(homeIndicatorInset))
        }
        .frame(maxWidth: .infinity)
        .background(RoomTabBarStyle.barFillGradient)
        .zIndex(1)
        .ignoresSafeArea(edges: .bottom)
        .opacity(isBusy ? 0.72 : 1)
        .allowsHitTesting(!isBusy)
        .animation(CozyTheme.spring, value: selectedTab)
    }

    private func resolvedHomeIndicatorInset(_ measured: CGFloat) -> CGFloat {
        if measured > 0 { return measured }
        let windowInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.bottom ?? 0
        return windowInset > 0 ? windowInset : 6
    }

    private func tabContentBottomPadding(_ homeIndicatorInset: CGFloat) -> CGFloat {
        max(homeIndicatorInset, 6)
    }

    private func tabItem(systemName: String, title: String, tab: MainRoomTab) -> some View {
        tabItem(
            assetName: nil,
            systemFallback: systemName,
            emojiFallback: nil,
            title: title,
            tab: tab
        )
    }

    private func tabItem(
        assetName: String?,
        systemFallback: String = "circle",
        emojiFallback: String? = nil,
        title: String,
        tab: MainRoomTab
    ) -> some View {
        let isActive = selectedTab == tab

        return Button {
            withAnimation(CozyTheme.spring) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isActive {
                        Capsule()
                            .fill(CozyTheme.panelInsetFill)
                            .overlay(Capsule().strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth))
                            .frame(width: 52, height: 28)
                    }
                    tabIcon(
                        assetName: assetName,
                        systemFallback: systemFallback,
                        emojiFallback: emojiFallback,
                        isActive: isActive
                    )
                }
                .frame(height: 28)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(CozyTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    @ViewBuilder
    private func tabIcon(
        assetName: String?,
        systemFallback: String,
        emojiFallback: String?,
        isActive: Bool
    ) -> some View {
        if let assetName, BipbiCharacterAssets.hasImage(assetName) {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .opacity(isActive ? 1 : 0.72)
        } else if let emojiFallback {
            Text(emojiFallback)
                .font(.system(size: 20))
                .opacity(isActive ? 1 : 0.72)
                .accessibilityHidden(true)
        } else {
            Image(systemName: systemFallback)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(
                    isActive
                        ? AnyShapeStyle(CozyTheme.deepBlue)
                        : AnyShapeStyle(CozyTheme.textPrimary.opacity(0.55))
                )
        }
    }
}
