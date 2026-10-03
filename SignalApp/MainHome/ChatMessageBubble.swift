//
//  ChatMessageBubble.swift
//  SignalApp
//

import SwiftUI

struct ChatMessageBubble: View {
    let message: MediaMessage
    let isMine: Bool
    var showReadReceipt: Bool = false
    var onMediaTap: ((URL) -> Void)? = nil

    private static let kakaoUnreadYellow = Color(red: 254 / 255, green: 229 / 255, blue: 0 / 255)

    private var showsMedia: Bool {
        message.type == "photo"
            || message.type == "drawing"
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if isMine { Spacer(minLength: 48) }
            if isMine, showReadReceipt {
                readReceiptMeta
            }
            bubbleContent
            if !isMine { Spacer(minLength: 48) }
        }
        .onAppear {
            if showsMedia {
                let raw = message.mediaUrl ?? "nil"
                print("🖼️ 이미지 렌더링 시도 URL:", MediaURLResolver.sanitizedRaw(raw) ?? raw)
            }
        }
    }

    private var readReceiptMeta: some View {
        HStack(spacing: 2) {
            if !message.isRead {
                Text("1")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Self.kakaoUnreadYellow)
                    .padding(.trailing, 2)
                    .transition(.opacity.combined(with: .scale))
            }
            Text(formattedTime)
                .font(.caption2)
                .foregroundStyle(CozyTheme.textSecondary)
        }
        .animation(.easeInOut, value: message.isRead)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: message.createdAt)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if showsMedia {
            mediaBubble
        } else {
            emojiBubble
        }
    }

    @ViewBuilder
    private var emojiBubble: some View {
        if message.type == "nudge" {
            let text = AppGroupStorage.keycapDisplayText(fromNudgeContent: message.content)
            Text(text.isEmpty ? "…" : text)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(red: 0.12, green: 0.11, blue: 0.10))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground)
                .overlay(bubbleStroke)
        } else {
            let emojiText = message.content ?? ""
            Text(emojiText.isEmpty ? "…" : emojiText)
                .font(.system(size: 30))
                .foregroundStyle(Color(red: 0.12, green: 0.11, blue: 0.10))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground)
                .overlay(bubbleStroke)
        }
    }

    private var mediaBubble: some View {
        let resolvedURL = SupabaseManager.shared.resolvePublicMediaURL(message.mediaUrl)

        return Group {
            if let resolvedURL {
                ChatRemoteImage(url: resolvedURL, cacheKey: message.id.uuidString)
            } else {
                mediaPlaceholder(label: "URL 없음")
                    .frame(maxWidth: 220, maxHeight: 220)
                    .onAppear {
                        print("⚠️ 📱 URL 변환 실패 raw=\(message.mediaUrl ?? "nil")")
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            if let resolvedURL {
                onMediaTap?(resolvedURL)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
        )
        .background(bubbleBackground)
    }

    private func mediaPlaceholder(label: String) -> some View {
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
    }

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isMine ? CozyTheme.accent.opacity(0.28) : Color.white)
    }

    private var bubbleStroke: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
    }
}
