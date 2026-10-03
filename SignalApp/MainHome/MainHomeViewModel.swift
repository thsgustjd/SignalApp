//
//  MainHomeViewModel.swift
//  SignalApp
//

import Foundation

@MainActor
final class MainHomeViewModel: ObservableObject {
    @Published private(set) var room: Room
    private(set) var senderNickname: String

    @Published var statusMessage: String?
    @Published var isSending = false

    private let manager = SupabaseManager.shared

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

    var partnerNickname: String? {
        let name = manager.partnerNickname(in: room)
        return name == "상대방" ? nil : name
    }

    func sendEmoji(_ text: String) async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        do {
            try await HeartWalletService.shared.consumeUsage(action: "emoji")
            _ = try await manager.sendEmojiMessage(
                roomId: room.id,
                senderNickname: senderNickname,
                content: text
            )
            flashStatus("메시지를 보냈어요 ✨")
        } catch {
            if let message = UserFacingErrorMessage.actionMessage(from: error) {
                flashStatus(message)
            }
        }
    }

    @discardableResult
    func sendPhoto(_ imageData: Data) async -> MediaMessage? {
        guard !isSending else { return nil }
        isSending = true
        defer { isSending = false }

        guard let jpeg = PhotoMediaPipeline.jpegData(from: imageData) else {
            flashStatus("사진을 처리하지 못했어요")
            return nil
        }

        do {
            try await HeartWalletService.shared.consumeUsage(action: "photo")
            let message = try await manager.sendPhotoMessage(
                roomId: room.id,
                senderNickname: senderNickname,
                jpegData: jpeg
            )
            flashStatus("사진을 보냈어요 📸")
            return message
        } catch {
            if let message = UserFacingErrorMessage.actionMessage(from: error) {
                flashStatus(message)
            }
            print("❌ [Photo] send 실패: \(error)")
            return nil
        }
    }

    @discardableResult
    func sendDrawing(_ imageData: Data) async -> MediaMessage? {
        guard !isSending else { return nil }
        isSending = true
        defer { isSending = false }

        guard let jpeg = PhotoMediaPipeline.jpegData(from: imageData) else {
            flashStatus("그림을 처리하지 못했어요")
            return nil
        }

        do {
            try await HeartWalletService.shared.consumeUsage(action: "drawing")
            let message = try await manager.sendDrawingMessage(
                roomId: room.id,
                senderNickname: senderNickname,
                jpegData: jpeg
            )
            flashStatus("그림을 보냈어요 🎨")
            return message
        } catch {
            if let message = UserFacingErrorMessage.actionMessage(from: error) {
                flashStatus(message)
            }
            return nil
        }
    }

    private func flashStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }

    func flashStatusPublic(_ message: String) {
        flashStatus(message)
    }

    @discardableResult
    func sendKeycap(_ symbolKey: String, bipbiBonus: String? = nil) async -> MediaMessage? {
        if isSending, let bipbiBonus {
            return await sendKeycapNudgeContent(bipbiBonus, flashOnSuccess: true)
        }

        guard !isSending else { return nil }
        isSending = true
        defer { isSending = false }

        do {
            try await HeartWalletService.shared.consumeUsage(action: "keycap")
            let docTrigger = AppGroupStorage.normalizedKeycapType("doc")
            let key = AppGroupStorage.normalizedKeycapType(symbolKey)
            // 삐삐 코드 완성(📞): 일반 키캡 INSERT는 유지, 상대 푸시는 bipbi 보너스 1회만 (뭐해?·사랑해 중복 방지).
            let suppressPrimaryPush = key == docTrigger && bipbiBonus != nil

            var last = try await manager.sendKeycapNudge(
                roomId: room.id,
                senderNickname: senderNickname,
                symbolKey: symbolKey,
                notifyPartner: !suppressPrimaryPush
            )
            if let last {
                flashKeycapSent(last)
            }
            if let bipbiBonus {
                let bonusMessage = try await manager.sendKeycapNudgeContent(
                    roomId: room.id,
                    senderNickname: senderNickname,
                    content: bipbiBonus,
                    notifyPartner: true
                )
                last = bonusMessage
                flashKeycapSent(bonusMessage)
            }
            return last
        } catch {
            if let message = UserFacingErrorMessage.actionMessage(from: error) {
                flashStatus(message)
            }
            return nil
        }
    }

    @discardableResult
    private func sendKeycapNudgeContent(_ content: String, flashOnSuccess: Bool) async -> MediaMessage? {
        do {
            let message = try await manager.sendKeycapNudgeContent(
                roomId: room.id,
                senderNickname: senderNickname,
                content: content
            )
            if flashOnSuccess {
                flashKeycapSent(message)
            }
            return message
        } catch {
            if let message = UserFacingErrorMessage.actionMessage(from: error) {
                flashStatus(message)
            }
            return nil
        }
    }

    private func flashKeycapSent(_ message: MediaMessage) {
        let flash = AppGroupStorage.keycapDisplayText(fromNudgeContent: message.content)
        let diaryKey = AppGroupStorage.keycapDiarySymbolKey(fromNudgeContent: message.content) ?? "nil"
        print(
            """
            📊 [KeycapDiary] sent OK type=\(message.type) id=\(message.id) \
            sender_id=\(message.senderId) diaryKey=\(diaryKey) content=\(message.content ?? "nil")
            """
        )
        NotificationCenter.default.post(
            name: .keycapDiaryShouldReload,
            object: room.id,
            userInfo: [KeycapDiaryReloadKeys.message: message]
        )
        flashStatus(flash)
    }

}
