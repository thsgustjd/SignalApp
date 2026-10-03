//
//  BipbiSquishCharacterView.swift
//  SignalApp
//
//  삐삐 탭 — 중앙 캐릭터 + 부위별 터치 반응 PNG (0.3초).
//

import SwiftUI
import UIKit

// MARK: - 스테이지

private enum BipbiStageLayout {
    static let horizontalInset: CGFloat = 16
    static let verticalInset: CGFloat = 8

    static func contentSize(in container: CGSize) -> CGSize {
        CGSize(
            width: max(1, container.width - horizontalInset * 2),
            height: max(1, container.height - verticalInset * 2)
        )
    }
}

private enum BipbiTouchFeedback {
    private static let impact = UIImpactFeedbackGenerator(style: .light)

    static func playTap() {
        impact.prepare()
        impact.impactOccurred(intensity: 0.65)
    }
}

// MARK: - 중앙 캐릭터 (삐삐 탭 본문)

struct BipbiSquishCenterStage: View {
    var body: some View {
        GeometryReader { geo in
            let contentSize = BipbiStageLayout.contentSize(in: geo.size)

            BipbiSquishCharacterView(canvasSize: contentSize)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, RoomTabBarLayout.scrollClearance)
        .accessibilityLabel("삐삐")
    }
}

// MARK: - 캐릭터 렌더

struct BipbiSquishCharacterView: View {
    /// 삐삐 탭 중앙 캐릭터 표시 배율 (비율 유지)
    static let characterDisplayScale: CGFloat = 1.4
    private static let reactionDisplayDuration: Duration = .seconds(0.3)
    private static let reactionDisplayScale: CGFloat = 0.85

    var canvasSize: CGSize = CGSize(width: 280, height: 280)

    @State private var activeReaction: BipbiBodyRegion?
    @State private var reactionDismissTask: Task<Void, Never>?

    private var layoutSide: CGFloat {
        min(canvasSize.width, canvasSize.height)
    }

    private var referenceImageSize: CGSize {
        if let ui = BipbiCharacterAssets.uiImage(for: .neutral) {
            return ui.size
        }
        return CGSize(width: layoutSide, height: layoutSide)
    }

    var body: some View {
        ZStack {
            characterLayer(pose: .neutral)
                .opacity(activeReaction == nil ? 1 : 0)

            if let region = activeReaction,
               BipbiCharacterAssets.uiImage(forRegion: region) != nil {
                characterLayer(reaction: region)
                    .transition(.opacity)
            }
        }
        .scaleEffect(Self.characterDisplayScale)
        .frame(width: canvasSize.width, height: canvasSize.height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    handleTouch(at: value.location)
                }
        )
        .animation(.easeInOut(duration: 0.12), value: activeReaction?.id)
        .onDisappear {
            reactionDismissTask?.cancel()
            reactionDismissTask = nil
        }
    }

    @ViewBuilder
    private func characterLayer(pose: BipbiCharacterAssets.Pose) -> some View {
        Group {
            if BipbiCharacterAssets.uiImage(for: pose) != nil {
                BipbiCharacterAssets.poseImage(pose)
                    .scaledToFit()
            } else {
                bipbiPlaceholder
            }
        }
    }

    @ViewBuilder
    private func characterLayer(reaction region: BipbiBodyRegion) -> some View {
        BipbiCharacterAssets.reactionImage(for: region)
            .scaledToFit()
            .scaleEffect(Self.reactionDisplayScale)
    }

    private func handleTouch(at location: CGPoint) {
        guard let normalized = BipbiAspectFitLayout.normalizedImagePoint(
            touchInContainer: location,
            containerSize: canvasSize,
            imageSize: referenceImageSize,
            displayScale: Self.characterDisplayScale
        ) else { return }

        guard let region = BipbiBodyRegion.region(atNormalizedPoint: normalized) else { return }
        guard BipbiCharacterAssets.uiImage(forRegion: region) != nil else { return }

        BipbiTouchFeedback.playTap()
        activeReaction = region

        reactionDismissTask?.cancel()
        reactionDismissTask = Task {
            try? await Task.sleep(for: Self.reactionDisplayDuration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if activeReaction == region {
                    activeReaction = nil
                }
            }
        }
    }

    private var bipbiPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: layoutSide * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1, green: 0.93, blue: 0.58),
                            Color(red: 1, green: 0.8, blue: 0.42),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Text("🐣")
                .font(.system(size: layoutSide * 0.28))
            Text("bipbi_pose_neutral")
                .font(.caption2.weight(.medium))
                .foregroundStyle(CozyTheme.textSecondary.opacity(0.7))
                .offset(y: layoutSide * 0.32)
        }
    }
}
