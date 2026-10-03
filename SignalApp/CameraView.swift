//
//  CameraView.swift
//  SignalApp
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraView: View {
    let room: Room
    var onLeaveRoom: (() -> Void)?

    @StateObject private var camera = CameraController()
    @State private var uploadCount = 0
    @State private var lastError: String?
    @State private var showSuccessToast = false
    @State private var showFeed = false
    @State private var nudgeTestMessage: String?

    private let manager = SupabaseManager.shared

    private var usesFallbackCapture: Bool {
        camera.usesFallbackCapture
    }

    private var canCapture: Bool {
        camera.isConfigured || usesFallbackCapture
    }

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer(minLength: 0)
            }
            .zIndex(1)

            VStack(spacing: 10) {
                if usesFallbackCapture {
                    Text("📸 탭하여 테스트 사진 전송")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                }

                shutterButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .padding(.top, 48)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .background {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            }
            .safeAreaPadding(.bottom, 4)
            .zIndex(2)

            if showSuccessToast {
                VStack {
                    Spacer()
                    Text("전송 완료!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(.green.opacity(0.9), in: Capsule())
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                        .padding(.bottom, 130)
                }
                .zIndex(3)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: showSuccessToast)
            }
        }
        .onAppear {
            manager.syncSharedState(room: room)
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
        .sheet(isPresented: $showFeed) {
            FeedView(room: room)
        }
        .alert("전송 실패", isPresented: Binding(
            get: { lastError != nil },
            set: { if !$0 { lastError = nil } }
        )) {
            Button("확인", role: .cancel) { lastError = nil }
        } message: {
            Text(lastError ?? "")
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if usesFallbackCapture {
            SimulatorPlaceholderBackground()
        } else if camera.isConfigured {
            CameraPreviewView(session: camera.session)
        } else {
            Color.black
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("카메라 준비 중…")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Text(room.inviteCode)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.5), in: Capsule())

            Button {
                showFeed = true
            } label: {
                Text("피드 보기")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.2), in: Capsule())
            }

            Spacer(minLength: 4)

            Text("연결됨 🟢")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.green.opacity(0.4), in: Capsule())

            Menu {
                Button {
                    manager.syncSharedState(room: room)
                } label: {
                    Label("위젯 새로고침", systemImage: "arrow.clockwise")
                }
                Button {
                    Task { await runNudgeTest() }
                } label: {
                    Label("넛지 테스트", systemImage: "bolt.fill")
                }
                Button(role: .destructive) {
                    onLeaveRoom?()
                } label: {
                    Label("방 나가기", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    @MainActor
    private func runNudgeTest() async {
        let result = await manager.sendTestNudge()
        switch result {
        case .sent:
            nudgeTestMessage = "넛지 OK"
        case .cooldown(let seconds):
            nudgeTestMessage = "쿨다운 \(seconds)s"
        case .notConfigured:
            nudgeTestMessage = "미연동"
        case .failed(let message):
            nudgeTestMessage = message
        }
        try? await Task.sleep(for: .seconds(2))
        nudgeTestMessage = nil
    }

    private var shutterButton: some View {
        Button {
            captureAndSend()
        } label: {
            ZStack {
                if uploadCount > 0 {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.35)
                        .frame(width: 75, height: 75)
                } else {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 75, height: 75)
                    Circle()
                        .fill(.white.opacity(0.82))
                        .frame(width: 65, height: 65)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!canCapture || camera.isCapturing || uploadCount > 0)
        .opacity(canCapture ? 1 : 0.45)
        .accessibilityLabel("사진 촬영")
    }

    private func captureAndSend() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if usesFallbackCapture {
            guard let data = SamplePhotoGenerator.makeJPEG() else {
                lastError = "테스트 이미지를 생성하지 못했습니다."
                return
            }
            sendMedia(data: data)
            return
        }

        camera.capturePhoto { data in
            guard let data else {
                lastError = "사진을 캡처하지 못했습니다."
                return
            }
            sendMedia(data: data)
        }
    }

    private func sendMedia(data: Data) {
        uploadCount += 1
        Task {
            defer { uploadCount -= 1 }
            do {
                _ = try await manager.uploadAndSendMedia(roomId: room.id, data: data, isVideo: false)
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showSuccessToast = true
                }
                try? await Task.sleep(for: .seconds(1.5))
                await MainActor.run {
                    showSuccessToast = false
                }
            } catch {
                await MainActor.run {
                    lastError = UserFacingErrorMessage.actionMessage(from: error)
                    if lastError != nil {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
            }
        }
    }
}

// MARK: - Simulator placeholder

private struct SimulatorPlaceholderBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.35, green: 0.58, blue: 0.78),
                Color(red: 0.12, green: 0.42, blue: 0.58),
                Color(red: 0.05, green: 0.10, blue: 0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private enum SamplePhotoGenerator {
    static func makeJPEG() -> Data? {
        let size = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [
                UIColor(red: 0.45, green: 0.72, blue: 0.95, alpha: 1).cgColor,
                UIColor(red: 0.20, green: 0.62, blue: 0.88, alpha: 1).cgColor,
                UIColor(red: 0.55, green: 0.82, blue: 0.98, alpha: 1).cgColor
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.55, 1]
            )!
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateStyle = .long
            formatter.timeStyle = .medium
            let timestamp = formatter.string(from: Date())

            let title = "Signal Test Shot"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 52, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.95)
            ]
            let timeAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 36, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.88)
            ]

            let titleSize = title.size(withAttributes: titleAttributes)
            let timeSize = timestamp.size(withAttributes: timeAttributes)
            let blockHeight = titleSize.height + 16 + timeSize.height
            let titleOrigin = CGPoint(
                x: (size.width - titleSize.width) / 2,
                y: (size.height - blockHeight) / 2
            )
            let timeOrigin = CGPoint(
                x: (size.width - timeSize.width) / 2,
                y: titleOrigin.y + titleSize.height + 16
            )

            title.draw(at: titleOrigin, withAttributes: titleAttributes)
            timestamp.draw(at: timeOrigin, withAttributes: timeAttributes)
        }
        return image.jpegData(compressionQuality: 0.88)
    }
}

// MARK: - Preview layer

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

// MARK: - Camera controller

final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var isConfigured = false
    @Published private(set) var isCapturing = false
    @Published private(set) var usesFallbackCapture = false

    private let sessionQueue = DispatchQueue(label: "com.hyunseong.SignalApp.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var photoCompletion: ((Data?) -> Void)?
    private var isSessionConfigured = false

    func start() {
        if shouldUseFallbackCaptureImmediately() {
            usesFallbackCapture = true
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureSessionIfNeeded()
            if !self.session.isRunning, self.isSessionConfigured {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        guard !usesFallbackCapture else { return }
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping (Data?) -> Void) {
        guard isConfigured, !isCapturing else {
            completion(nil)
            return
        }

        isCapturing = true
        photoCompletion = completion

        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                settings.flashMode = .off
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func shouldUseFallbackCaptureImmediately() -> Bool {
#if targetEnvironment(simulator)
        return true
#else
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return true
        }
        return !CameraHardware.isAvailable
#endif
    }

    private func configureSessionIfNeeded() {
        guard !isSessionConfigured else { return }

        guard CameraHardware.isAvailable else {
            DispatchQueue.main.async { self.usesFallbackCapture = true }
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        defer {
            session.commitConfiguration()
        }

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            DispatchQueue.main.async { self.usesFallbackCapture = true }
            return
        }

        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            DispatchQueue.main.async { self.usesFallbackCapture = true }
            return
        }

        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .speed
        isSessionConfigured = true

        DispatchQueue.main.async {
            self.isConfigured = true
        }
    }
}

private enum CameraHardware {
    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = photo.fileDataRepresentation()
        DispatchQueue.main.async {
            self.isCapturing = false
            self.photoCompletion?(error == nil ? data : nil)
            self.photoCompletion = nil
        }
    }
}

#Preview {
    CameraView(
        room: Room(
            id: UUID(),
            inviteCode: "Ab12Cd34Ef56",
            user1Id: "user-1",
            user2Id: "user-2",
            user1Name: "Host",
            user2Name: "Guest"
        )
    )
}
