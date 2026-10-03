//
//  EmojiChatViewModel.swift
//  SignalApp
//

import Foundation
import UIKit

@MainActor
final class EmojiChatViewModel: ObservableObject {
    @Published private(set) var room: Room
    private(set) var senderNickname: String

    @Published private(set) var messages: [MediaMessage] = []
    @Published private var blockFilterEpoch = 0
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var drawingSurpriseMessage: MediaMessage?
    @Published var nudgeBannerText: String?

    private let manager = SupabaseManager.shared
    private var realtimeTask: Task<Void, Never>?
    private var nudgeBannerDismissTask: Task<Void, Never>?
    private var chatDayToken: String = SupabaseManager.chatDayToken()

    init(room: Room, senderNickname: String) {
        self.room = room
        self.senderNickname = senderNickname
    }

    func syncRoom(_ updated: Room) {
        guard updated != room else { return }
        room = updated
    }

    func updateSenderNickname(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        senderNickname = trimmed
    }

    var partnerNickname: String {
        manager.partnerNickname(in: room)
    }

    var showsSenderNames: Bool {
        manager.chatShowsSenderNames(for: room)
    }

    func resolvedSenderName(for message: MediaMessage) -> String {
        if let nick = message.senderNickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nick.isEmpty {
            return nick
        }
        if let fromRoom = manager.memberDisplayName(userId: message.senderId, in: room) {
            return fromRoom
        }
        return partnerNickname
    }

    var myUserId: String {
        manager.currentUserId
    }

    var visibleMessages: [MediaMessage] {
        _ = blockFilterEpoch
        return messages.filter { message in
            message.senderId == myUserId || !UserSafetyStore.isBlocked(message.senderId)
        }
    }

    func refreshBlockedFilter() {
        blockFilterEpoch += 1
        messages.removeAll { $0.senderId != myUserId && UserSafetyStore.isBlocked($0.senderId) }
    }

    deinit {
        realtimeTask?.cancel()
    }

    func loadMessages() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            chatDayToken = SupabaseManager.chatDayToken()
            let fetched = try await manager.fetchChatMessages(roomId: room.id)
            messages = fetched
            print("✅ [Chat] 오늘 메시지 \(fetched.count)건 (emoji/photo/drawing)")
            await markMessagesAsRead()
        } catch {
            errorMessage = UserFacingErrorMessage.loadMessage(from: error)
            print("❌ [Chat] load 실패: \(error)")
        }
    }

    /// Foreground 진입·자정(significant time change) 시 오늘 기준으로 목록 재조회.
    func refreshMessagesIfDayChanged() async {
        let token = SupabaseManager.chatDayToken()
        if token != chatDayToken {
            await loadMessages()
            return
        }
        messages.removeAll { !SupabaseManager.isCreatedOnChatToday($0.createdAt) }
    }

    func startRealtimeSubscription() {
        realtimeTask?.cancel()
        realtimeTask = Task { @MainActor in
            await runRealtimeSubscriptions()
        }
    }

    private func runRealtimeSubscriptions() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await self.subscribeToMessageInserts()
            }
            group.addTask { @MainActor in
                await self.subscribeToMessageUpdates()
            }
        }
    }

    private func subscribeToMessageInserts() async {
        for await message in manager.watchChatMessageInserts(roomId: room.id) {
            guard !Task.isCancelled else { break }
            mergeIncoming(message, isFromRealtime: true)
            if message.senderId != myUserId {
                await markMessagesAsRead()
            }
        }
    }

    private func subscribeToMessageUpdates() async {
        for await message in manager.watchChatMessageUpdates(roomId: room.id) {
            guard !Task.isCancelled else { break }
            applyReadUpdate(message)
        }
    }

    func markMessagesAsRead() async {
        await manager.markMessagesAsRead(roomId: room.id)
    }

    func applyReadUpdate(_ updated: MediaMessage) {
        guard SupabaseManager.isChatVisibleMessage(updated) else { return }
        guard SupabaseManager.isCreatedOnChatToday(updated.createdAt) else { return }
        if let index = messages.firstIndex(where: { $0.id == updated.id }) {
            messages[index] = updated
        }
    }

    func stopRealtimeSubscription() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    func dismissDrawingSurprise() {
        drawingSurpriseMessage = nil
    }

    /// APNs 탭/포그라운 수신으로 손그림 팝업을 띄울 때 (Realtime 피드백과 중복 방지).
    func presentDrawingSurpriseFromPush(_ message: MediaMessage) {
        guard message.type == "drawing" else { return }
        guard message.senderId != myUserId else { return }
        guard !AppGroupStorage.isSignalDNDActive else { return }
        drawingSurpriseMessage = message
        mergeIncoming(message, isFromRealtime: false)
    }

    func mergeIncoming(_ message: MediaMessage, isFromRealtime: Bool = false) {
        guard SupabaseManager.isCreatedOnChatToday(message.createdAt) else { return }

        if isFromRealtime, message.senderId != myUserId {
            handlePartnerRealtimeMessage(message)
        }

        guard SupabaseManager.isChatVisibleMessage(message) else { return }
        if message.senderId != myUserId, UserSafetyStore.isBlocked(message.senderId) { return }
        if messages.contains(where: { $0.id == message.id }) { return }

        if message.senderId == myUserId,
           let pendingIndex = messages.lastIndex(where: { pending in
               pending.id != message.id
                   && pending.senderId == myUserId
                   && pending.type == message.type
                   && abs(pending.createdAt.timeIntervalSince(message.createdAt)) < 60
                   && pendingMatchesServer(pending: pending, server: message)
           }) {
            messages[pendingIndex] = message
            return
        }

        messages.append(message)
        messages.sort { $0.createdAt < $1.createdAt }
    }

    private func handlePartnerRealtimeMessage(_ message: MediaMessage) {
        if UserSafetyStore.isBlocked(message.senderId) { return }

        let isEmergency = message.type == AppGroupStorage.emergencyNudgeType
        if AppGroupStorage.isSignalDNDActive && !isEmergency { return }

        if isEmergency {
            IncomingHapticFeedback.playEmergencyAlarm()
        } else if message.type == "nudge", BipbiPagerEasterEgg.isBipbiNudgeContent(message.content) {
            BipbiIncomingSound.playIfBipbiNudge(content: message.content)
        } else {
            IncomingHapticFeedback.playKeycapTap()
        }

        let appState = UIApplication.shared.applicationState

        if appState == .active {
            // 포그라운드: INSERT 시 notifyPartnerPush가 이미 APNs 1회 발송. Realtime에서 Edge 재호출 시 넛지가 두 번 뜸(예: 뭐해?×2).
            switch message.type {
            case "drawing", "photo":
                Task { await deliverPartnerMessageViaAPNs(message) }
            default:
                break
            }
        } else {
            // 백그라운드·종료: INSERT 시 notifyPartnerPush / 위젯 Edge Function이 상대에게 APNs 발송
            print("🔔 [Push] Realtime partner message type=\(message.type) appState=\(appState.rawValue) — remote APNs 경로 사용")
        }

        if message.type == "drawing" {
            drawingSurpriseMessage = message
        } else if message.type == AppGroupStorage.emergencyNudgeType {
            presentNudgeBanner(text: "🚨 비상")
        } else if message.type == "nudge" {
            let banner = ChatIncomingNotifications.nudgeBannerText(
                content: message.content,
                senderName: resolvedSenderName(for: message)
            )
            presentNudgeBanner(text: banner)
        }

        if appState != .active {
            ChatIncomingNotifications.scheduleLocalNotification(
                for: message,
                partnerName: resolvedSenderName(for: message)
            )
        }
    }

    /// 앱 사용 중 Realtime만 먼저 도착할 때 — APNs 배너(앱 아이콘). 로컬 알림은 실기기 격자 아이콘 이슈로 쓰지 않음.
    private func deliverPartnerMessageViaAPNs(_ message: MediaMessage) async {
        let imageURL: String? = {
            guard message.type == "drawing" || message.type == "photo" else { return nil }
            return SupabaseManager.shared.resolvePublicMediaURL(message.mediaUrl)?.absoluteString
        }()

        let nickname = resolvedSenderName(for: message)
        let roomTitle = RoomPushTitleCache.resolvedDisplayTitle(
            for: message.roomId,
            fallbackDefault: SupabaseManager.shared.defaultRoomTitle(for: room)
        )

        await MessagePushClient.send(
            recipientId: myUserId,
            messageId: message.id,
            roomId: message.roomId,
            senderId: message.senderId,
            senderNickname: nickname,
            messageType: message.type,
            content: message.content,
            imageURL: imageURL,
            roomDisplayTitle: roomTitle
        )
    }

    private func presentNudgeBanner(text: String) {
        nudgeBannerText = text
        nudgeBannerDismissTask?.cancel()
        nudgeBannerDismissTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            if nudgeBannerText == text {
                nudgeBannerText = nil
            }
        }
    }

    private func pendingMatchesServer(pending: MediaMessage, server: MediaMessage) -> Bool {
        if server.type == "nudge" {
            return pending.content == server.content
                || AppGroupStorage.keycapDisplayText(fromNudgeContent: pending.content)
                    == AppGroupStorage.keycapDisplayText(fromNudgeContent: server.content)
        }
        if server.type == "emoji" {
            return pending.content == server.content
        }
        if let pendingURL = pending.mediaUrl, let serverURL = server.mediaUrl,
           !pendingURL.isEmpty, !serverURL.isEmpty {
            return pendingURL == serverURL
        }
        return false
    }

    func sendEmoji(_ raw: String) async {
        let content = EmojiOnlyFilter.sanitized(raw)
        print("보내는 이모지:", content)

        guard EmojiOnlyFilter.canSend(content) else {
            print("⚠️ [EmojiChat] 전송 차단 — 필터 후 비어 있음 raw=\(raw)")
            return
        }
        guard !isSending else { return }

        let pendingId = UUID()
        let optimistic = MediaMessage(
            id: pendingId,
            roomId: room.id,
            type: "emoji",
            senderId: myUserId,
            senderNickname: senderNickname,
            mediaUrl: nil,
            content: content,
            createdAt: Date()
        )
        messages.append(optimistic)

        isSending = true
        defer { isSending = false }

        do {
            try await HeartWalletService.shared.consumeUsage(action: "emoji")
            let saved = try await manager.sendEmojiMessage(
                roomId: room.id,
                senderNickname: senderNickname,
                content: content
            )
            replacePending(id: pendingId, with: saved)
            print("✅ [EmojiChat] 서버 저장 완료 id=\(saved.id) content=\(saved.content ?? "")")
        } catch {
            messages.removeAll { $0.id == pendingId }
            errorMessage = UserFacingErrorMessage.actionMessage(from: error)
            print("❌ [EmojiChat] send 실패: \(error)")
        }
    }

    private func replacePending(id: UUID, with saved: MediaMessage) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index] = saved
        } else {
            mergeIncoming(saved)
        }
        messages.sort { $0.createdAt < $1.createdAt }
    }
}
