//
//  DrawingCanvasView.swift
//  SignalApp
//

import PencilKit
import SwiftUI
import UIKit

struct DrawingCanvasView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var canvasView = PKCanvasView()
    @State private var selectedColor: UIColor = DrawingPalette.colors[0].uiColor
    @State private var canvasSize: CGSize = .zero
    @State private var showEmptyDrawingAlert = false
    @State private var hasDrawing = false

    let isSending: Bool
    let onSend: (Data) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                paletteRow

                GeometryReader { proxy in
                    let side = min(proxy.size.width, proxy.size.height)

                    CanvasRepresentable(
                        canvasView: $canvasView,
                        canvasSide: side,
                        hasDrawing: $hasDrawing
                    )
                    .frame(width: side, height: side)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        canvasSize = CGSize(width: side, height: side)
                    }
                    .onChange(of: side) { _, newSide in
                        canvasSize = CGSize(width: newSide, height: newSide)
                    }
                }
                .background(Color.white)
            }
            .padding(16)
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("그림 보내기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            clearCanvas()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("전체 지우기")

                        Button("전송") {
                            exportAndSend()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(hasDrawing ? CozyTheme.accent : CozyTheme.textSecondary)
                        .disabled(isSending)
                    }
                }
            }
            .onAppear {
                canvasView.drawingPolicy = .anyInput
                canvasView.backgroundColor = .white
                canvasView.isOpaque = true
                canvasView.overrideUserInterfaceStyle = .light
                applyPen(color: selectedColor)
                syncHasDrawingFromCanvas()
            }
            .alert("그림이 없어요", isPresented: $showEmptyDrawingAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("캔버스에 그린 뒤 전송해 주세요.")
            }
        }
        .background(Color.white.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    private var paletteRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DrawingPalette.colors) { item in
                    Button {
                        selectedColor = item.uiColor
                        applyPen(color: item.uiColor)
                    } label: {
                        Circle()
                            .fill(Color(item.uiColor))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        selectedColor == item.uiColor ? CozyTheme.accent : Color.clear,
                                        lineWidth: 3
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func applyPen(color: UIColor) {
        canvasView.tool = PKInkingTool(.pen, color: color, width: 5)
    }

    private func clearCanvas() {
        canvasView.drawing = PKDrawing()
        hasDrawing = false
    }

    private func syncHasDrawingFromCanvas() {
        hasDrawing = !canvasView.drawing.bounds.isEmpty
    }

    private func exportAndSend() {
        let drawing = canvasView.drawing
        guard !drawing.bounds.isEmpty else {
            hasDrawing = false
            showEmptyDrawingAlert = true
            return
        }

        let size = canvasSize.width > 0 ? canvasSize : canvasView.bounds.size
        guard let data = PKDrawingExporter.jpegData(from: drawing, canvasSize: size) else {
            showEmptyDrawingAlert = true
            return
        }

        print("✅ [Drawing] export bounds=\(drawing.bounds) canvas=\(size) bytes=\(data.count)")
        onSend(data)
        dismiss()
    }
}

private enum DrawingPalette {
    struct ColorItem: Identifiable {
        let id: String
        let uiColor: UIColor
    }

    static let colors: [ColorItem] = [
        .init(id: "black", uiColor: UIColor(red: 0.12, green: 0.11, blue: 0.10, alpha: 1)),
        .init(id: "red", uiColor: .systemRed),
        .init(id: "blue", uiColor: .systemBlue),
        .init(id: "green", uiColor: .systemGreen),
        .init(id: "yellow", uiColor: .systemYellow),
        .init(id: "pink", uiColor: .systemPink),
        .init(id: "brown", uiColor: .brown),
        .init(id: "sky", uiColor: UIColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1)),
        .init(id: "lightGreen", uiColor: UIColor(red: 0.55, green: 0.88, blue: 0.35, alpha: 1)),
        .init(id: "orange", uiColor: .systemOrange),
        .init(id: "purple", uiColor: .systemPurple)
    ]
}

private struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var canvasSide: CGFloat
    @Binding var hasDrawing: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(hasDrawing: $hasDrawing)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.delegate = context.coordinator
        canvasView.backgroundColor = .white
        canvasView.isOpaque = true
        canvasView.overrideUserInterfaceStyle = .light
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.delegate !== context.coordinator {
            uiView.delegate = context.coordinator
        }
        uiView.backgroundColor = .white
        uiView.isOpaque = true
        uiView.overrideUserInterfaceStyle = .light

        guard canvasSide > 0 else { return }
        let target = CGSize(width: canvasSide, height: canvasSide)
        if uiView.bounds.size != target {
            uiView.frame = CGRect(origin: .zero, size: target)
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var hasDrawing: Bool

        init(hasDrawing: Binding<Bool>) {
            _hasDrawing = hasDrawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let inkPresent = Self.drawingHasInk(canvasView.drawing)
            DispatchQueue.main.async {
                if self.hasDrawing != inkPresent {
                    self.hasDrawing = inkPresent
                }
            }
        }

        private static func drawingHasInk(_ drawing: PKDrawing) -> Bool {
            !drawing.bounds.isEmpty || drawing.strokes.count > 0
        }
    }
}
