//
//  MessagePushService.swift
//  SignalApp
//

import Foundation

/// 메시지 INSERT 후 상대 `profiles.apns_token`으로 Edge Function → APNs 발송.
enum MessagePushService {
    static func send(message: MediaMessage, room: Room) async {
        let recipients = SupabaseManager.shared.recipientUserIds(in: room, excluding: message.senderId)
        guard !recipients.isEmpty else {
            print("⚠️ [MessagePush] 수신자 없음 — 방 멤버십 확인 필요")
            return
        }

        let imageURL: String? = {
            guard message.type == "drawing" || message.type == "photo" else { return nil }
            return SupabaseManager.shared.resolvePublicMediaURL(message.mediaUrl)?.absoluteString
        }()

        if message.type == "drawing", imageURL == nil {
            print("⚠️ [MessagePush] drawing image_url 없음 raw=\(message.mediaUrl ?? "nil")")
        }

        let nickname = message.senderNickname
            ?? SupabaseManager.shared.savedNickname
            ?? "상대방"

        let roomTitle = RoomPushTitleCache.resolvedDisplayTitle(
            for: message.roomId,
            fallbackDefault: SupabaseManager.shared.defaultRoomTitle(for: room)
        )

        for recipientId in recipients {
            guard recipientId != message.senderId else { continue }
            print(
                """
                🧭 [MessagePush] sender_id=\(message.senderId) → recipient_id=\(recipientId)
                """
            )
            await MessagePushClient.send(
                recipientId: recipientId,
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
    }
}
