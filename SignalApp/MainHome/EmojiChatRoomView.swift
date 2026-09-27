//
//  ChatRoomView.swift (EmojiChatRoomView.swift)
//  SignalApp
//

import SwiftUI
import UIKit
import PhotosUI

/// 매칭 후 기본 메인 화면 — 하단 2탭(키캡 전체 / 채팅방) + 사진·손그림 전송.
struct ChatRoomView: View {
    let room: Room
    let senderNickname: String
    var onLeaveRoom: (() -> Void)?

    @StateObject private var chatModel: EmojiChatViewModel
    @StateObject private var mediaModel: MainHomeViewModel
    @State private var mainRoomTab: MainRoomTab = .keycaps
    @State private var showCamera = false
    @State private var showDrawing = false
    @State private var showInviteCopiedToast = false
    @State private var isShowingKeycapCustomSheet = false
    @State private var showCalendar = false
    @State private var showPhotoSourceDialog = false
    @State private var showPhotosPicker = false
    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var lightboxURL: URL?
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var pushRouter: PushNotificationRouter

    @State private var showSafetyMenu = false
    @State private var reportSheetContext: ReportSheetContext?

    init(room: Room, senderNickname: String, onLeaveRoom: (() -> Void)? = nil) {
        self.room = room
        self.senderNickname = senderNickname
        self.onLeaveRoom = onLeaveRoom
        _chatModel = StateObject(
            wrappedValue: EmojiChatViewModel(room: room, senderNickname: senderNickname)
        )
        _mediaModel = StateObject(
            wrappedValue: MainHomeViewModel(room: room, senderNickname: senderNickname)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
                mainContent
                if mainRoomTab == .chatRoom {
                    chatMediaActionBar
                }
                MainRoomTabBar(
                    selectedTab: $mainRoomTab,
                    isBusy: mediaModel.isSending || chatModel.isSending || isUploadingPhoto
                )
            }
            .animation(CozyTheme.spring, value: mainRoomTab)
            .background(CozyTheme.roomBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    inviteCodeChip
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(SupabaseManager.shared.defaultRoomTitle(for: chatModel.room))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(CozyTheme.textPrimary)
                            .lineLimit(1)
                        Text(SupabaseManager.shared.memberCountLabel(for: chatModel.room))
                            .font(.caption2)
                            .foregroundStyle(CozyTheme.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            isShowingKeycapCustomSheet = true
                        } label: {
                            Image(systemName: "keyboard")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(CozyTheme.textPrimary)
                        }
                        Button {
                            showCalendar = true
                        } label: {
                            Image(systemName: "calendar")
                                .foregroundStyle(CozyTheme.textSecondary)
                        }
                        Menu {
                            Button {
                                showSafetyMenu = true
                            } label: {
                                Label("안전 및 데이터", systemImage: "shield")
                            }
                            Button(role: .destructive) {
                                Task { await leaveCurrentRoom() }
                            } label: {
                                Label("방 나가기", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(CozyTheme.textSecondary)
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    if let nudgeBanner = chatModel.nudgeBannerText {
                        Text(nudgeBanner)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CozyTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(CozyTheme.accent.opacity(0.35), lineWidth: 1)
                            )
                            .padding(.horizontal, 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if showInviteCopiedToast {
                        Text("초대코드가 복사되었습니다")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.82), in: Capsule())
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    statusBanner
                }
                .padding(.top, 4)
            }
            .animation(CozyTheme.spring, value: chatModel.nudgeBannerText)
            .overlay {
                if let surprise = chatModel.drawingSurpriseMessage {
                    DrawingSurpriseModal(
                        message: surprise,
                        partnerName: chatModel.partnerNickname,
                        onDismiss: { chatModel.dismissDrawingSurprise() }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .zIndex(200)
                }
            }
            .animation(.spring(response: 0.48, dampingFraction: 0.78), value: chatModel.drawingSurpriseMessage?.id)
            .sheet(isPresented: $showSafetyMenu) {
            NavigationStack {
                RoomSafetyMenuView(
                    room: chatModel.room,
                    senderNickname: senderNickname,
                    onLeaveRoom: {
                        showSafetyMenu = false
                        onLeaveRoom?()
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { showSafetyMenu = false }
                    }
                }
            }
        }
        .sheet(item: $reportSheetContext) { ctx in
            NavigationStack {
                ReportContentView(
                    room: ctx.room,
                    message: ctx.message,
                    preselectedUserId: ctx.preselectedUserId,
                    reporterNickname: senderNickname
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { reportSheetContext = nil }
                    }
                }
            }
        }
        .task {
                SupabaseManager.shared.syncSharedState(room: room, nickname: senderNickname)
                chatModel.syncRoom(room)
                mediaModel.syncRoom(room)
                await chatModel.loadMessages()
                chatModel.startRealtimeSubscription()
            }
            .onChange(of: SupabaseManager.shared.roomMembershipRevision(for: room)) { _, _ in
                chatModel.syncRoom(room)
                mediaModel.syncRoom(room)
            }
            .onAppear {
                Task { await chatModel.markMessagesAsRead() }
                applyPendingDrawingPushIfNeeded()
            }
            .onChange(of: pushRouter.pendingDrawingMessage?.id) { _, _ in
                applyPendingDrawingPushIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        if let refreshed = await SupabaseManager.shared.refreshPersistedRoomIfNeeded() {
                            chatModel.syncRoom(refreshed)
                            mediaModel.syncRoom(refreshed)
                        }
                        await chatModel.refreshMessagesIfDayChanged()
                        await chatModel.markMessagesAsRead()
                    }
                    applyPendingDrawingPushIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                Task { await chatModel.refreshMessagesIfDayChanged() }
            }
            .onDisappear {
                chatModel.stopRealtimeSubscription()
            }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showCalendar) {
            CalendarArchiveView(
                roomId: room.id,
                myUserId: chatModel.myUserId,
                myDisplayName: senderNickname,
                partnerDisplayName: chatModel.partnerNickname,
                statMemberColumns: CalendarArchiveView.statMemberColumns(
                    room: room,
                    myUserId: chatModel.myUserId,
                    myDisplayName: senderNickname,
                    partnerDisplayName: chatModel.partnerNickname
                )
            )
        }
        .sheet(isPresented: $isShowingKeycapCustomSheet) {
            KeycapCustomView()
        }
        .sheet(isPresented: $showDrawing) {
            DrawingCanvasView(isSending: mediaModel.isSending) { data in
                Task {
                    if let message = await mediaModel.sendDrawing(data) {
                        await MainActor.run {
                            chatModel.mergeIncoming(message)
                            mainRoomTab = .chatRoom
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onCapture: { data in
                    Task {
                        if let message = await mediaModel.sendPhoto(data) {
                            await MainActor.run {
                                chatModel.mergeIncoming(message)
                                mainRoomTab = .chatRoom
                            }
                        }
                    }
                },
                onCancel: {}
            )
            .ignoresSafeArea()
        }
        .confirmationDialog("사진 보내기", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
            Button("사진 찍기") {
                showCamera = true
            }
            Button("앨범에서 선택") {
                showPhotosPicker = true
            }
            Button("취소", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPickerItem, matching: .images)
        .onChange(of: selectedPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                defer {
                    Task { @MainActor in selectedPickerItem = nil }
                }
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let jpeg = PhotoMediaPipeline.jpegData(from: data) else {
                    await MainActor.run {
                        mediaModel.flashStatusPublic("앨범 사진을 불러오지 못했어요")
                    }
                    return
                }
                await MainActor.run { isUploadingPhoto = true }
                defer { Task { @MainActor in isUploadingPhoto = false } }
                if let message = await mediaModel.sendPhoto(jpeg) {
                    await MainActor.run {
                        chatModel.mergeIncoming(message)
                        mainRoomTab = .chatRoom
                    }
                }
            }
        }
        .fullScreenCover(isPresented: lightboxPresented) {
            if let lightboxURL {
                ImageDetailView(imageURL: lightboxURL)
            }
        }
    }

    private var lightboxPresented: Binding<Bool> {
        Binding(
            get: { lightboxURL != nil },
            set: { isPresented in
                if !isPresented { lightboxURL = nil }
            }
        )
    }

    @ViewBuilder
    private var statusBanner: some View {
        VStack(spacing: 6) {
            if let error = chatModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.85), in: Capsule())
            }
            if let status = mediaModel.statusMessage {
                Text(status)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CozyTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(.top, 8)
        .animation(CozyTheme.spring, value: chatModel.errorMessage)
        .animation(CozyTheme.spring, value: mediaModel.statusMessage)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if chatModel.isLoading && chatModel.messages.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    }

                    ForEach(chatModel.visibleMessages) { message in
                        let isMine = message.senderId == chatModel.myUserId
                        VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                            if chatModel.showsSenderNames, !isMine {
                                Text(message.senderNickname?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                                     ? message.senderNickname!
                                     : "멤버")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(CozyTheme.textSecondary)
                                    .padding(.leading, 4)
                            }
                            ChatMessageBubble(
                                message: message,
                                isMine: isMine,
                                showReadReceipt: isMine,
                                onMediaTap: { url in
                                    lightboxURL = url
                                }
                            )
                            .contextMenu {
                                if !isMine {
                                    Button {
                                        reportSheetContext = ReportSheetContext(
                                            room: chatModel.room,
                                            message: message,
                                            preselectedUserId: message.senderId
                                        )
                                    } label: {
                                        Label("신고", systemImage: "exclamationmark.bubble")
                                    }
                                    Button(role: .destructive) {
                                        let name = chatModel.resolvedSenderName(for: message)
                                        UserSafetyStore.block(userId: message.senderId, displayName: name)
                                        chatModel.refreshBlockedFilter()
                                    } label: {
                                        Label("차단", systemImage: "person.crop.circle.badge.xmark")
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: chatModel.visibleMessages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatModel.visibleMessages.last?.id) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = chatModel.visibleMessages.last {
            withAnimation(CozyTheme.spring) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func leaveCurrentRoom() async {
        try? await SupabaseManager.shared.leaveRoom(chatModel.room)
        onLeaveRoom?()
    }

    private func applyPendingDrawingPushIfNeeded() {
        guard let message = pushRouter.consumePendingDrawing(forRoomId: room.id) else { return }
        chatModel.presentDrawingSurpriseFromPush(message)
    }

    private var inviteCodeChip: some View {
        Button {
            copyInviteCode()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "number")
                    .font(.system(size: 11, weight: .bold))
                Text(room.inviteCode)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(CozyTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(CozyTheme.accent.opacity(0.18))
            )
            .overlay(
                Capsule()
                    .strokeBorder(CozyTheme.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("초대 코드 복사")
    }

    private func copyInviteCode() {
        UIPasteboard.general.string = room.inviteCode
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(CozyTheme.spring) {
            showInviteCopiedToast = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(CozyTheme.spring) {
                    showInviteCopiedToast = false
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch mainRoomTab {
        case .keycaps:
            fullScreenKeycapPanel
        case .chatRoom:
            messageList
        }
    }

    private var fullScreenKeycapPanel: some View {
        ScrollView {
            VStack(spacing: 18) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                    ],
                    spacing: 14
                ) {
                    ForEach(AppGroupStorage.keycapNudgeTypeOrder, id: \.self) { type in
                        ChatKeycapSendButton(symbolKey: type) {
                            Task { _ = await mediaModel.sendKeycap(type) }
                        }
                    }
                }

                EmergencyKeycapSendButton {
                    Task { _ = await mediaModel.sendEmergency() }
                }
                .frame(maxWidth: 172)
                .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chatMediaActionBar: some View {
        HStack(spacing: 12) {
            Button {
                showPhotoSourceDialog = true
            } label: {
                Label("사진", systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(CozyTheme.textPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.78))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(CozyTheme.pink.opacity(0.45), lineWidth: 1.5)
                            )
                            .shadow(color: CozyTheme.pink.opacity(0.2), radius: 6, y: 2)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isUploadingPhoto || mediaModel.isSending)

            Button {
                showDrawing = true
            } label: {
                Label("손그림", systemImage: "pencil.and.scribble")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(CozyTheme.textPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.78))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(CozyTheme.lavender.opacity(0.5), lineWidth: 1.5)
                            )
                            .shadow(color: CozyTheme.lavender.opacity(0.22), radius: 6, y: 2)
                    )
            }
            .buttonStyle(.plain)
            .disabled(mediaModel.isSending)

            if isUploadingPhoto {
                ProgressView()
                    .tint(CozyTheme.lavender)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            CozyTheme.sand.opacity(0.4)
                .overlay(CozyTheme.card.opacity(0.9))
        )
        .overlay(alignment: .top) {
            Divider().overlay(CozyTheme.lavender.opacity(0.25))
        }
    }
}

/// 이전 이름 호환 (프리뷰·참조용)
typealias EmojiChatRoomView = ChatRoomView

#Preview {
    ChatRoomView(
        room: Room(
            id: UUID(),
            inviteCode: "Ab12Cd34Ef56",
            user1Id: "a",
            user2Id: "b",
            user1Name: "mint",
            user2Name: "latte"
        ),
        senderNickname: "mint"
    )
    .environmentObject(PushNotificationRouter.shared)
}
