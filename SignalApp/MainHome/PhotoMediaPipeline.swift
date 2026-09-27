//
//  PhotoMediaPipeline.swift
//  SignalApp
//

import UIKit

/// 카메라 촬영·앨범 선택 공통: JPEG 압축 후 Supabase 업로드용.
enum PhotoMediaPipeline {
    static let jpegQuality: CGFloat = 0.75

    /// JPEG는 알파를 지원하지 않아 투명 영역이 검게 나옴 → 흰 바탕에 합성.
    static func imageOnWhiteBackground(_ image: UIImage) -> UIImage {
        guard imageHasAlpha(image) else { return image }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true

        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func jpegData(from image: UIImage) -> Data? {
        imageOnWhiteBackground(image).jpegData(compressionQuality: jpegQuality)
    }

    static func jpegData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else {
            return data.isEmpty ? nil : data
        }
        return jpegData(from: image)
    }

    private static func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        switch cg.alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly:
            return true
        default:
            return false
        }
    }
}
