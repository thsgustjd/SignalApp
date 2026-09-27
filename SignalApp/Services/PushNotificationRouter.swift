//
//  PushNotificationRouter.swift
//  SignalApp
//

import Foundation

struct PushMessagePayload: Equatable {
    let messageType: String
    let messageId: UUID?
    let roomId: UUID?
    let mediaUrl: String?
    let senderId: String?
    let senderNickname: String?
    let content: String?

    func asMediaMessage(fallbackRoomId: UUID? = nil) -> MediaMessage? {
        let resolvedRoom = roomId ?? fallbackRoomId
        guard let resolvedRoom else { return nil }

        let normalizedType: String
        switch messageType {
        case "text", "emoji":
            normalizedType = "emoji"
        case "drawing", "nudge", "photo":
            normalizedType = messageType
        default:
            normalizedType = messageType
        }

        return MediaMessage(
            id: messageId ?? UUID(),
            roomId: resolvedRoom,
            type: normalizedType,
            senderId: senderId ?? "",
            senderNickname: senderNickname,
            mediaUrl: mediaUrl,
            content: content,
            createdAt: Date(),
            isRead: false
        )
    }
}

enum PushPayloadParser {
    static func parse(_ userInfo: [AnyHashable: Any]) -> PushMessagePayload? {
        let flattened = flatten(userInfo)

        guard let messageType = string(flattened, keys: ["message_type", "messageType", "type"])
            ?? (string(flattened, keys: ["image_url", "imageUrl"]) != nil ? "drawing" : nil)
        else {
            return nil
        }

        return PushMessagePayload(
            messageType: messageType,
            messageId: uuid(flattened, keys: ["message_id", "messageId", "id"]),
            roomId: uuid(flattened, keys: ["room_id", "roomId"]),
            mediaUrl: string(flattened, keys: ["image_url", "imageUrl", "media_url", "mediaUrl"]),
            senderId: string(flattened, keys: ["sender_id", "senderId"]),
            senderNickname: string(flattened, keys: ["sender_nickname", "senderNickname"]),
            content: string(flattened, keys: ["content", "body"])
        )
    }

    private static func flatten(_ userInfo: [AnyHashable: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in userInfo {
            if let key = key as? String {
                result[key] = value
            }
        }
        if let custom = userInfo["data"] as? [String: Any] {
            for (key, value) in custom {
                result[key] = value
            }
        }
        return result
    }

    private static func string(_ dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func uuid(_ dict: [String: Any], keys: [String]) -> UUID? {
        guard let raw = string(dict, keys: keys) else { return nil }
        return UUID(uuidString: raw)
    }
}

@MainActor
final class PushNotificationRouter: ObservableObject {
    static let shared = PushNotificationRouter()

    @Published private(set) var pendingDrawingMessage: MediaMessage?

    private init() {}

    func handleForegroundPresentation(userInfo: [AnyHashable: Any]) {
        guard let payload = PushPayloadParser.parse(userInfo) else { return }
        guard payload.messageType == "drawing" else { return }
        guard let message = payload.asMediaMessage() else { return }
        guard message.senderId != SupabaseManager.shared.currentUserId else { return }
        pendingDrawingMessage = message
    }

    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let payload = PushPayloadParser.parse(userInfo) else { return }
        guard payload.messageType == "drawing" else { return }
        guard let message = payload.asMediaMessage() else { return }
        guard message.senderId != SupabaseManager.shared.currentUserId else { return }
        pendingDrawingMessage = message
    }

    func consumePendingDrawing(forRoomId roomId: UUID) -> MediaMessage? {
        guard let pending = pendingDrawingMessage else { return nil }
        guard pending.roomId == roomId else { return nil }
        pendingDrawingMessage = nil
        return pending
    }

    func clearPendingDrawing() {
        pendingDrawingMessage = nil
    }
}
