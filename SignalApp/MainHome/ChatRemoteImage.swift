//
//  ChatRemoteImage.swift
//  SignalApp
//

import SwiftUI
import UIKit

/// `AsyncImage` 대신 URLSession으로 로드 — 실기기에서 URL/HTTP 오류 로그 확인용.
struct ChatRemoteImage: View {
    let url: URL
    var cacheKey: String = ""

    @State private var uiImage: UIImage?
    @State private var didFail = false

    private var taskIdentity: String {
        cacheKey.isEmpty ? url.absoluteString : "\(cacheKey)|\(url.absoluteString)"
    }

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 220)
            } else if didFail {
                placeholder(label: "이미지 로드 실패")
            } else {
                ZStack {
                    Color.white.opacity(0.9)
                    ProgressView()
                }
                .frame(maxWidth: 220, maxHeight: 220)
            }
        }
        .task(id: taskIdentity) {
            await loadImage()
        }
    }

    private func loadImage() async {
        uiImage = nil
        didFail = false

        let urlString = url.absoluteString
        print("📱 실기기 이미지 다운로드 시도 URL: \(urlString)")

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse {
                print("📱 이미지 HTTP \(http.statusCode) bytes=\(data.count) url=\(urlString.prefix(80))…")
                guard (200 ... 299).contains(http.statusCode) else {
                    didFail = true
                    return
                }
            }

            guard let image = UIImage(data: data) else {
                print("❌ 📱 UIImage 디코딩 실패 bytes=\(data.count)")
                didFail = true
                return
            }

            uiImage = PhotoMediaPipeline.imageOnWhiteBackground(image)
        } catch {
            print("❌ 📱 이미지 다운로드 실패: \(error.localizedDescription) url=\(urlString.prefix(80))…")
            didFail = true
        }
    }

    private func placeholder(label: String) -> some View {
        ZStack {
            Color(red: 0.94, green: 0.92, blue: 0.88)
            VStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(CozyTheme.textSecondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(CozyTheme.textSecondary)
            }
        }
        .frame(maxWidth: 220, maxHeight: 220)
    }
}
