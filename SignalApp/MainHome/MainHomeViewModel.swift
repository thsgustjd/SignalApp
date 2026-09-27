//
//  MainHomeViewModel.swift
//  SignalApp
//

import Foundation

@MainActor
final class MainHomeViewModel: ObservableObject {
    @Published private(set) var room: Room
    let senderNickname: String

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

    var partnerNickname: String? {
        let name = manager.partnerNickname(in: room)
        return name == "상대방" ? nil : name
    }

    func sendEmoji(_ text: String) async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        do {
            _ = try await manager.sendEmojiMessage(
                roomId: room.id,
                senderNickname: senderNickname,
                content: text
            )
            flashStatus("메시지를 보냈어요 ✨")
        } catch {
            flashStatus(error.localizedDescription)
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
            let message = try await manager.sendPhotoMessage(
                roomId: room.id,
                senderNickname: senderNickname,
                jpegData: jpeg
            )
            flashStatus("사진을 보냈어요 📸")
            return message
        } catch {
            flashStatus(error.localizedDescription)
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
            let message = try await manager.sendDrawingMessage(
                roomId: room.id,
                senderNickname: senderNickname,
                jpegData: jpeg
            )
            flashStatus("그림을 보냈어요 🎨")
            return message
        } catch {
            flashStatus(error.localizedDescription)
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
    func sendKeycap(_ symbolKey: String) async -> MediaMessage? {
        guard !isSending else { return nil }
        isSending = true
        defer { isSending = false }

        do {
            let text = AppGroupStorage.getMessage(for: symbolKey)
            let message = try await manager.sendKeycapNudge(
                roomId: room.id,
                senderNickname: senderNickname,
                symbolKey: symbolKey
            )
            flashStatus(text)
            return message
        } catch {
            flashStatus(error.localizedDescription)
            return nil
        }
    }

    @discardableResult
    func sendEmergency() async -> MediaMessage? {
        guard !isSending else { return nil }
        isSending = true
        defer { isSending = false }

        do {
            let message = try await manager.sendEmergencyNudge(
                roomId: room.id,
                senderNickname: senderNickname
            )
            flashStatus("🚨 비상 알림을 보냈어요")
            return message
        } catch {
            flashStatus(error.localizedDescription)
            return nil
        }
    }
}
