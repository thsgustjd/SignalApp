//
//  BipbiCharacterAssets.swift
//  SignalApp
//
//  삐삐 캐릭터 — 통짜 PNG 5장 (Assets.xcassets Image Set 이름과 동일).
//

import SwiftUI
import UIKit

enum BipbiCharacterAssets {
    /// 하단 탭 아이콘 (선택, 없으면 SF Symbol)
    static let tabIcon = "bipbi_tab_icon"

    /// 기본 · 일반 표정 — **지금 넣을 파일**
    static let poseNeutral = "bipbi_pose_neutral"
    /// 살짝 찌그러짐
    static let poseSquishLight = "bipbi_pose_squish_light"
    /// 많이 찌그러짐
    static let poseSquishHeavy = "bipbi_pose_squish_heavy"
    /// 살짝 늘림
    static let poseStretchLight = "bipbi_pose_stretch_light"
    /// 많이 늘림
    static let poseStretchHeavy = "bipbi_pose_stretch_heavy"

    enum Pose: CaseIterable {
        case neutral
        case squishLight
        case squishHeavy
        case stretchLight
        case stretchHeavy

        var assetName: String {
            switch self {
            case .neutral: return poseNeutral
            case .squishLight: return poseSquishLight
            case .squishHeavy: return poseSquishHeavy
            case .stretchLight: return poseStretchLight
            case .stretchHeavy: return poseStretchHeavy
            }
        }
    }

    static func hasImage(_ name: String) -> Bool {
        uiImage(assetName: name) != nil
    }

    /// Image Set `bipbi_pose_neutral` (내부 파일 `bbibbi_main.png` 등).
    static func uiImage(for pose: Pose) -> UIImage? {
        if let img = uiImage(assetName: pose.assetName) { return img }
        if pose != .neutral, let neutral = uiImage(assetName: poseNeutral) { return neutral }
        return uiImage(assetName: poseNeutral)
    }

    private static func uiImage(assetName: String) -> UIImage? {
        if let img = UIImage(named: assetName, in: .main, compatibleWith: nil) {
            return img
        }
        return nil
    }

    /// 해당 포즈 PNG 없으면 `bipbi_pose_neutral` → 없으면 nil(폴백 도형).
    static func resolvedAssetName(for pose: Pose) -> String? {
        if hasImage(pose.assetName) { return pose.assetName }
        if pose != .neutral, hasImage(poseNeutral) { return poseNeutral }
        if hasImage(poseNeutral) { return poseNeutral }
        return nil
    }

    @ViewBuilder
    static func poseImage(_ pose: Pose) -> some View {
        if let ui = uiImage(for: pose) {
            bipbiImageView(ui)
        }
    }

    static func uiImage(forRegion region: BipbiBodyRegion) -> UIImage? {
        uiImage(assetName: region.reactionAssetName)
    }

    @ViewBuilder
    static func reactionImage(for region: BipbiBodyRegion) -> some View {
        if let ui = uiImage(forRegion: region) {
            bipbiImageView(ui)
        }
    }

    @ViewBuilder
    private static func bipbiImageView(_ ui: UIImage) -> some View {
        Image(uiImage: ui)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
    }
}
