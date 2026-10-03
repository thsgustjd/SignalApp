//
//  BipbiBodyRegion.swift
//  SignalApp
//
//  삐삐 캐릭터 부위별 0~1 정규화 히트박스 (bbibbi_main 기준).
//

import CoreGraphics
import UIKit

struct BipbiNormalizedHitbox {
    let xMin: CGFloat
    let yMin: CGFloat
    let xMax: CGFloat
    let yMax: CGFloat

    var area: CGFloat {
        max(0, xMax - xMin) * max(0, yMax - yMin)
    }

    func contains(normalizedX x: CGFloat, normalizedY y: CGFloat) -> Bool {
        x >= xMin && x <= xMax && y >= yMin && y <= yMax
    }
}

enum BipbiBodyRegion: String, CaseIterable, Identifiable {
    case crest
    case forehead
    case eyes
    case beak
    case leftCheek
    case rightCheek
    case leftArm
    case rightArm
    case belly
    case leftToe
    case rightToe

    var id: String { rawValue }

    var hitbox: BipbiNormalizedHitbox {
        switch self {
        case .crest:
            return .init(xMin: 0.42, yMin: 0.08, xMax: 0.58, yMax: 0.22)
        case .forehead:
            return .init(xMin: 0.35, yMin: 0.22, xMax: 0.65, yMax: 0.32)
        case .eyes:
            return .init(xMin: 0.33, yMin: 0.31, xMax: 0.67, yMax: 0.45)
        case .beak:
            return .init(xMin: 0.44, yMin: 0.37, xMax: 0.56, yMax: 0.48)
        case .leftCheek:
            return .init(xMin: 0.23, yMin: 0.42, xMax: 0.38, yMax: 0.58)
        case .rightCheek:
            return .init(xMin: 0.62, yMin: 0.42, xMax: 0.77, yMax: 0.58)
        case .leftArm:
            return .init(xMin: 0.23, yMin: 0.45, xMax: 0.32, yMax: 0.72)
        case .rightArm:
            return .init(xMin: 0.68, yMin: 0.45, xMax: 0.77, yMax: 0.72)
        case .belly:
            return .init(xMin: 0.332, yMin: 0.462, xMax: 0.668, yMax: 0.768)
        case .leftToe:
            return .init(xMin: 0.28, yMin: 0.715, xMax: 0.42, yMax: 0.795)
        case .rightToe:
            return .init(xMin: 0.58, yMin: 0.715, xMax: 0.72, yMax: 0.795)
        }
    }

    /// Assets.xcassets Image Set 이름
    var reactionAssetName: String {
        switch self {
        case .crest: return "bipbi_reaction_angry"
        case .forehead: return "bipbi_reaction_why"
        case .eyes: return "bipbi_reaction_thatstoomuch"
        case .beak: return "bipbi_reaction_tease"
        case .leftCheek: return "bipbi_reaction_kyu"
        case .rightCheek: return "bipbi_reaction_no2"
        case .leftArm: return "bipbi_reaction_yes"
        case .rightArm: return "bipbi_reaction_hello"
        case .belly: return "bipbi_reaction_heung"
        case .leftToe: return "bipbi_reaction_no1"
        case .rightToe: return "bipbi_reaction_sulk"
        }
    }

    /// 겹치는 영역은 더 작은 히트박스 우선
    static func region(atNormalizedPoint point: CGPoint) -> BipbiBodyRegion? {
        let x = point.x
        let y = point.y
        let candidates = allCases
            .filter { $0.hitbox.contains(normalizedX: x, normalizedY: y) }
            .sorted { $0.hitbox.area < $1.hitbox.area }
        return candidates.first
    }
}

enum BipbiAspectFitLayout {
    /// `scaledToFit` 이미지가 차지하는 사각형 (컨테이너 좌표).
    static func contentRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0
        else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let scale = min(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        let origin = CGPoint(
            x: (containerSize.width - width) * 0.5,
            y: (containerSize.height - height) * 0.5
        )
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    /// 터치(컨테이너 좌표) → 0~1 이미지 정규 좌표. `displayScale`은 `scaleEffect` 배율.
    static func normalizedImagePoint(
        touchInContainer touch: CGPoint,
        containerSize: CGSize,
        imageSize: CGSize,
        displayScale: CGFloat
    ) -> CGPoint? {
        let center = CGPoint(x: containerSize.width * 0.5, y: containerSize.height * 0.5)
        let preScale = CGPoint(
            x: center.x + (touch.x - center.x) / displayScale,
            y: center.y + (touch.y - center.y) / displayScale
        )
        let rect = contentRect(imageSize: imageSize, in: containerSize)
        guard rect.contains(preScale) else { return nil }
        return CGPoint(
            x: (preScale.x - rect.minX) / rect.width,
            y: (preScale.y - rect.minY) / rect.height
        )
    }
}
