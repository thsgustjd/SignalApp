//
//  FeedView.swift
//  SignalApp
//

import SwiftUI

struct FeedView: View {
    let room: Room

    @Environment(\.dismiss) private var dismiss

    @State private var messages: [MediaMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let manager = SupabaseManager.shared
    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && messages.isEmpty {
                    ProgressView("불러오는 중…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if messages.isEmpty {
                    ContentUnavailableView(
                        "아직 공유된 사진이 없어요",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("셔터를 눌러 첫 사진을 보내 보세요.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 14) {
                            ForEach(messages) { message in
                                FeedMessageCard(
                                    message: message,
                                    isMine: message.senderId == manager.currentUserId
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.09))
            .navigationTitle("피드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadMessages() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .refreshable {
                await loadMessages()
            }
            .overlay(alignment: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.red.opacity(0.85), in: Capsule())
                        .padding(.bottom, 16)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadMessages()
        }
    }

    @MainActor
    private func loadMessages() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            messages = try await manager.fetchMessages(roomId: room.id)
        } catch {
            errorMessage = UserFacingErrorMessage.loadMessage(from: error)
        }
    }
}

private struct FeedMessageCard: View {
    let message: MediaMessage
    let isMine: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.type == "nudge" {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.35), Color.orange.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(minHeight: 100)
                    .overlay {
                        Text(AppGroupStorage.keycapDisplayText(fromNudgeContent: message.content))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(12)
                    }
            } else if let urlString = message.mediaUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay { ProgressView().tint(.white) }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(minHeight: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(minHeight: 100)
                    .overlay {
                        Text("미디어 없음")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
            }

            HStack(spacing: 6) {
                Text(isMine ? "나" : "상대방")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isMine ? .white : .green)
                Text("·")
                    .foregroundStyle(.white.opacity(0.35))
                Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                )
        )
    }
}

#Preview {
    FeedView(
        room: Room(
            id: UUID(),
            inviteCode: "Ab12Cd34Ef56",
            user1Id: "a",
            user2Id: "b",
            user1Name: "a",
            user2Name: "b"
        )
    )
}
