//
//  ImageDetailView.swift
//  SignalApp
//

import SwiftUI
import UIKit

struct ImageDetailView: View {
    let imageURL: URL

    @Environment(\.dismiss) private var dismiss

    @State private var uiImage: UIImage?
    @State private var loadFailed = false
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var dismissDrag: CGFloat = 0
    @State private var showSavedToast = false

    var body: some View {
        ZStack {
            Color.black.opacity(backgroundOpacity)
                .ignoresSafeArea()

            if let uiImage {
                imageContent(uiImage)
                    .offset(y: dismissDrag)
            } else if loadFailed {
                Text("이미지를 불러올 수 없어요")
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                ProgressView()
                    .tint(.white)
            }

            VStack {
                topBar
                Spacer()
            }

            if showSavedToast {
                VStack {
                    Spacer()
                    Text("저장 완료")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75), in: Capsule())
                        .padding(.bottom, 40)
                }
                .transition(.opacity)
            }
        }
        .task(id: imageURL) {
            await loadImage()
        }
    }

    private var backgroundOpacity: Double {
        let fade = 1 - min(abs(dismissDrag) / 280, 0.45)
        return 0.92 * fade
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button {
                saveToPhotoLibrary()
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .disabled(uiImage == nil)
            .opacity(uiImage == nil ? 0.4 : 1)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private func imageContent(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .gesture(magnifyGesture)
            .simultaneousGesture(dismissDragGesture)
            .padding(24)
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(3, max(1, baseScale * value))
            }
            .onEnded { value in
                baseScale = min(3, max(1, baseScale * value))
                scale = baseScale
            }
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let vertical = abs(value.translation.height) > abs(value.translation.width)
                if vertical, value.translation.height > 0 {
                    dismissDrag = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > 120 {
                    dismiss()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        dismissDrag = 0
                    }
                }
            }
    }

    private func loadImage() async {
        uiImage = nil
        loadFailed = false
        scale = 1
        baseScale = 1
        dismissDrag = 0

        do {
            var request = URLRequest(url: imageURL)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 30
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                loadFailed = true
                return
            }
            guard let image = UIImage(data: data) else {
                loadFailed = true
                return
            }
            uiImage = image
        } catch {
            loadFailed = true
        }
    }

    private func saveToPhotoLibrary() {
        guard let uiImage else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        PhotoLibrarySaver.save(uiImage) { success in
            guard success else { return }
            withAnimation {
                showSavedToast = true
            }
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                await MainActor.run {
                    withAnimation {
                        showSavedToast = false
                    }
                }
            }
        }
    }
}

private enum PhotoLibrarySaver {
    static func save(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        ImageSaveHandler.shared.completion = completion
        UIImageWriteToSavedPhotosAlbum(image, ImageSaveHandler.shared, #selector(ImageSaveHandler.shared.didFinishSaving(_:didFinishSavingWithError:contextInfo:)), nil)
    }
}

private final class ImageSaveHandler: NSObject {
    static let shared = ImageSaveHandler()
    var completion: ((Bool) -> Void)?

    @objc func didFinishSaving(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer?) {
        completion?(error == nil)
        completion = nil
    }
}
