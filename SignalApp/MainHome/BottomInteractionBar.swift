//
//  BottomInteractionBar.swift
//  SignalApp
//

import SwiftUI

enum MainRoomTab: Equatable {
    case keycaps
    case chatRoom
}

struct MainRoomTabBar: View {
    @Binding var selectedTab: MainRoomTab
    let isBusy: Bool

    var body: some View {
        HStack(spacing: 0) {
            tabButton(
                systemName: "square.grid.3x3.fill",
                title: "키캡",
                tab: .keycaps
            )
            tabButton(
                systemName: "bubble.left.and.bubble.right.fill",
                title: "채팅방",
                tab: .chatRoom
            )
        }
        .padding(.top, 4)
        .padding(.bottom, 0)
        .padding(.horizontal, 12)
        .background {
            CozyTheme.card.opacity(0.94)
                .overlay(alignment: .top) {
                    Divider().overlay(CozyTheme.lavender.opacity(0.25))
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(systemName: String, title: String, tab: MainRoomTab) -> some View {
        let isActive = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 1) {
                ZStack {
                    if isActive {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        CozyTheme.pink.opacity(0.65),
                                        CozyTheme.lavender.opacity(0.4),
                                        .clear,
                                    ],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 26
                                )
                            )
                            .frame(width: 48, height: 48)
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [CozyTheme.pink.opacity(0.55), CozyTheme.lavender.opacity(0.45)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 40, height: 40)
                            .shadow(color: CozyTheme.pink.opacity(0.35), radius: 6, y: 1)
                    }

                    Image(systemName: systemName)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(isActive ? CozyTheme.textPrimary : CozyTheme.textSecondary.opacity(0.85))
                        .shadow(color: isActive ? CozyTheme.pink.opacity(0.45) : .clear, radius: 4)
                }
                .frame(height: 40)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isActive ? CozyTheme.textPrimary : CozyTheme.textSecondary)
                    .padding(.bottom, 2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.65 : 1)
    }
}
