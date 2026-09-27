//
//  DrawingSurpriseModal.swift
//  SignalApp
//

import SwiftUI

struct DrawingSurpriseModal: View {
    let message: MediaMessage
    let partnerName: String
    var onDismiss: () -> Void

    @State private var isPresented = false

    private var resolvedURL: URL? {
        SupabaseManager.shared.resolvePublicMediaURL(message.mediaUrl)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture { dismiss() }

            VStack(spacing: 20) {
                Text("💌 \(partnerName) 님이 방금 그림을 보냈어요!")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CozyTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Group {
                    if let resolvedURL {
                        ChatRemoteImage(url: resolvedURL, cacheKey: message.id.uuidString)
                            .frame(maxWidth: 280, maxHeight: 320)
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 240, height: 240)
                            .overlay {
                                Text("그림을 불러올 수 없어요")
                                    .font(.caption)
                                    .foregroundStyle(CozyTheme.textSecondary)
                            }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
                )

                Button("확인") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 12)
                .background(CozyTheme.accent, in: Capsule())
            }
            .padding(.horizontal, 20)
            .scaleEffect(isPresented ? 1 : 0.88)
            .opacity(isPresented ? 1 : 0)
        }
        .onAppear {
            IncomingHapticFeedback.playKeycapTap()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                isPresented = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isPresented = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss()
        }
    }
}
