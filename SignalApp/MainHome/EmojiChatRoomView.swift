//
//  ChatRoomView.swift (EmojiChatRoomView.swift)
//  SignalApp
//

import SwiftUI
import UIKit
/// 매칭 후 기본 메인 화면 — 하단 3탭 + 삐삐(말랑이) 툴바.
struct ChatRoomView: View {
    let room: Room
    let senderNickname: String
    var onLeaveRoom: (() -> Void)?

    @StateObject private var chatModel: EmojiChatViewModel
    @StateObject private var mediaModel: MainHomeViewModel
    @State private var mainRoomTab: MainRoomTab = .keycaps
    @State private var showInviteCopiedToast = false
    @State private var showCalendar = false
    @State private var lightboxURL: URL?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var pushRouter: PushNotificationRouter

    @State private var showSafetyMenu = false
    @State private var reportSheetContext: ReportSheetContext?
    @State private var showParticipantsList = false

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
            chatRoomTopBar

            ZStack(alignment: .bottom) {
                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                roomBottomChrome
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(CozyTheme.spring, value: mainRoomTab)
        .background(CozyTheme.roomBackground.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
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
                                    .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
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
                .padding(.top, 52)
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
        .sheet(isPresented: $showParticipantsList) {
            ChatRoomParticipantsSheet(room: chatModel.room)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
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

    /// 시스템 `ToolbarItem` 대신 커스텀 바 — UIBarButtonItem 흰/글래스 크롬 없음.
    private var chatRoomTopBar: some View {
        HStack(alignment: .center, spacing: 4) {
            HStack(spacing: 4) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(CozyTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로")

                inviteCodeCapsule
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showParticipantsList = true
            } label: {
                VStack(spacing: 2) {
                    Text(SupabaseManager.shared.chatRoomTopBarTitle(for: chatModel.room))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CozyTheme.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                    Text(SupabaseManager.shared.memberCountLabel(for: chatModel.room))
                        .font(.caption2)
                        .foregroundStyle(CozyTheme.textSecondary)
                        .lineLimit(1)
                }
                .multilineTextAlignment(.center)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("참여자 목록 보기")

            chatRoomTopBarTrailingActions
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: 44)
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .padding(.bottom, 8)
        .padding(.top, 4)
        .background(Color.clear)
    }

    private var chatRoomTopBarTrailingActions: some View {
        HStack(spacing: 12) {
            Button {
                showCalendar = true
            } label: {
                ChatRoomTopBarToolbarIcon(systemName: "calendar")
            }
            .buttonStyle(.plain)

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
                ChatRoomTopBarToolbarIcon(systemName: "ellipsis.circle")
            }
        }
    }

    private var inviteCodeCapsule: some View {
        RoomInviteCodeCapsuleLabel(code: room.inviteCode)
            .onTapGesture(perform: copyInviteCode)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("초대 코드 \(room.inviteCode), 탭하면 복사")
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

    private var roomBottomChrome: some View {
        MainRoomTabBar(
            selectedTab: $mainRoomTab,
            isBusy: mediaModel.isSending || chatModel.isSending
        )
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch mainRoomTab {
            case .keycapSettings:
                KeycapCustomView(
                    embeddedInTabBar: true,
                    room: chatModel.room,
                    onRoomUpdated: { updated in
                        chatModel.syncRoom(updated)
                        mediaModel.syncRoom(updated)
                        if let nick = SupabaseManager.shared.myNickname(in: updated) {
                            chatModel.updateSenderNickname(nick)
                            mediaModel.updateSenderNickname(nick)
                            SupabaseManager.shared.syncSharedState(room: updated, nickname: nick)
                        }
                    }
                )
            case .keycaps:
                fullScreenKeycapPanel
            case .chatRoom:
                BipbiSquishCenterStage()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .center)))
        .id(mainRoomTab)
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
                            let bipbiBonus = BipbiPagerEasterEgg.recordTap(symbolKey: type)
                            Task { _ = await mediaModel.sendKeycap(type, bipbiBonus: bipbiBonus) }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, RoomTabBarLayout.scrollClearance)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

/// 시스템 네비 툴바 trailing 아이콘과 동일한 크기·터치 영역 (방 코드 스타일과 분리).
private struct ChatRoomParticipantsSheet: View {
    let room: Room
    @Environment(\.dismiss) private var dismiss

    private var labels: [String] {
        SupabaseManager.shared.participantDisplayLabels(in: room)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(labels.enumerated()), id: \.offset) { _, name in
                        Text(name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(CozyTheme.textPrimary)
                    }
                } header: {
                    Text("참여 중인 닉네임")
                } footer: {
                    Text("채팅방 설정에서 방마다 보이는 이름을 바꿀 수 있어요.")
                }
            }
            .navigationTitle("참여 중")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(CozyTheme.textPrimary)
                }
            }
        }
    }
}

private struct ChatRoomTopBarToolbarIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(CozyTheme.textSecondary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
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
