//
//  PKDrawingExporter.swift
//  SignalApp
//

import PencilKit
import UIKit

enum PKDrawingExporter {
    /// 화면에 보이는 정사각 캔버스 전체를 1:1 비율로 export (왜곡 방지).
    static func jpegData(
        from drawing: PKDrawing,
        canvasSize: CGSize,
        scale: CGFloat = 2
    ) -> Data? {
        guard !drawing.bounds.isEmpty else { return nil }

        let exportRect: CGRect
        if canvasSize.width > 1, canvasSize.height > 1 {
            exportRect = CGRect(origin: .zero, size: canvasSize)
        } else {
            guard let inkRect = inkBoundsRect(drawing: drawing, strokePadding: 12) else {
                return nil
            }
            exportRect = inkRect
        }

        let strokeImage = drawing.image(from: exportRect, scale: scale)
        let image = PhotoMediaPipeline.imageOnWhiteBackground(strokeImage)
        print("✅ [DrawingExport] rect=\(exportRect) scale=\(scale) px=\(image.size)")
        return PhotoMediaPipeline.jpegData(from: image)
    }

    /// 잉크 영역만 필요할 때 (미리보기 등).
    static func inkBoundsRect(drawing: PKDrawing, strokePadding: CGFloat = 12) -> CGRect? {
        let inkBounds = drawing.bounds
        guard !inkBounds.isEmpty else { return nil }
        return inkBounds.insetBy(dx: -strokePadding, dy: -strokePadding)
    }
}
