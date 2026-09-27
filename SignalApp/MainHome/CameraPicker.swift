//
//  CameraPicker.swift
//  SignalApp
//

import PhotosUI
import SwiftUI
import UIKit

/// 실기기: 카메라. 시뮬레이터 등 카메라 불가: 사진 앨범(또는 PHPicker) 폴백.
struct CameraPicker: View {
    @Environment(\.dismiss) private var dismiss

    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    private let source = PhotoCaptureSource.resolved()

    var body: some View {
        ZStack(alignment: .top) {
            pickerContent
                .ignoresSafeArea()

            if source != .camera {
                Text(source.fallbackBannerText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(.top, 16)
            }
        }
    }

    @ViewBuilder
    private var pickerContent: some View {
        switch source {
        case .camera:
            UIImagePickerRepresentable(
                sourceType: .camera,
                onCapture: deliverJPEG,
                onCancel: cancel
            )
        case .photoLibrary:
            UIImagePickerRepresentable(
                sourceType: .photoLibrary,
                onCapture: deliverJPEG,
                onCancel: cancel
            )
        case .photosPicker:
            PHPickerRepresentable(onCapture: deliverJPEG, onCancel: cancel)
        }
    }

    private func deliverJPEG(from image: UIImage) {
        guard let data = PhotoMediaPipeline.jpegData(from: image) else {
            print("⚠️ [CameraPicker] JPEG 변환 실패")
            cancel()
            return
        }
        print("✅ [CameraPicker] source=\(source.logLabel) bytes=\(data.count)")
        onCapture(data)
        dismiss()
    }

    private func cancel() {
        onCancel()
        dismiss()
    }
}

private enum PhotoCaptureSource {
    case camera
    case photoLibrary
    case photosPicker

    static func resolved() -> PhotoCaptureSource {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            return .camera
        }
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            return .photoLibrary
        }
        return .photosPicker
    }

    var logLabel: String {
        switch self {
        case .camera: return "camera"
        case .photoLibrary: return "photoLibrary"
        case .photosPicker: return "photosPicker"
        }
    }

    var fallbackBannerText: String {
        switch self {
        case .camera:
            return ""
        case .photoLibrary, .photosPicker:
            return "카메라 없음 · 앨범에서 사진 선택"
        }
    }
}

// MARK: - UIImagePickerController

private struct UIImagePickerRepresentable: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        if sourceType == .camera {
            picker.cameraCaptureMode = .photo
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            } else {
                onCancel()
            }
        }
    }
}

// MARK: - PHPicker (최종 폴백)

private struct PHPickerRepresentable: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onCancel()
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [onCapture, onCancel] object, error in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        onCapture(image)
                    } else {
                        if let error {
                            print("⚠️ [CameraPicker] PHPicker 로드 실패: \(error)")
                        }
                        onCancel()
                    }
                }
            }
        }
    }
}
