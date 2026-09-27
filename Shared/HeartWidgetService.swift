//
//  HeartWidgetService.swift
//  SignalApp + SignalWidgetExtension
//

import Foundation

enum HeartWidgetService {
    private static let minSendInterval: TimeInterval = 0.25
    /// 채팅 말풍선에는 노출되지 않는 `nudge` 레코드용 content — 키캡 문구만 저장.
    static func sendHeart(symbolKey: String) async -> NudgeSendResult {
        guard AppGroupStorage.isWidgetSendConfigured,
              let roomId = AppGroupStorage.resolvedWidgetRoomUUID,
              let senderId = AppGroupStorage.currentUserId else {
            return .notConfigured
        }

        let senderNickname = AppGroupStorage.currentSenderNickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pushNickname = (senderNickname?.isEmpty == false) ? senderNickname! : "me"

        if AppGroupStorage.isWidgetHeartThrottled(minInterval: minSendInterval) {
            return .cooldown(remainingSeconds: 0)
        }

        do {
            let text = AppGroupStorage.getMessage(for: symbolKey)
            let content = text
            let messageId = UUID()
            try await insertHeartNudge(
                roomId: roomId,
                senderId: senderId,
                messageId: messageId,
                content: content
            )
            AppGroupStorage.recordWidgetHeartSent()

            let recipients = await MessagePushClient.recipientUserIds(roomId: roomId, senderId: senderId)
            let roomTitle = AppGroupStorage.pushRoomDisplayTitle(for: roomId) ?? "채팅방"
            for recipientId in recipients {
                await MessagePushClient.send(
                    recipientId: recipientId,
                    messageId: messageId,
                    roomId: roomId,
                    senderId: senderId,
                    senderNickname: pushNickname,
                    messageType: "nudge",
                    content: content,
                    imageURL: nil,
                    roomDisplayTitle: roomTitle
                )
            }

            return .sent
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// 🚨 비상 — 방해금지·일반 넛지 쿨다운과 별도.
    static func sendEmergency() async -> NudgeSendResult {
        guard AppGroupStorage.isWidgetSendConfigured,
              let roomId = AppGroupStorage.resolvedWidgetRoomUUID,
              let senderId = AppGroupStorage.currentUserId else {
            return .notConfigured
        }

        let senderNickname = AppGroupStorage.currentSenderNickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pushNickname = (senderNickname?.isEmpty == false) ? senderNickname! : "me"

        if AppGroupStorage.isEmergencyOnCooldown() {
            let phase = AppGroupStorage.emergencyInteractionPhase()
            if case .cooldown(let remaining) = phase {
                return .cooldown(remainingSeconds: remaining)
            }
            return .cooldown(remainingSeconds: 60)
        }

        do {
            let content = AppGroupStorage.emergencyDisplayText
            let messageId = UUID()
            try await insertEmergencyAlert(
                roomId: roomId,
                senderId: senderId,
                messageId: messageId,
                content: content
            )
            AppGroupStorage.lastEmergencySentAt = Date()

            let recipients = await MessagePushClient.recipientUserIds(roomId: roomId, senderId: senderId)
            let roomTitle = AppGroupStorage.pushRoomDisplayTitle(for: roomId) ?? "채팅방"
            for recipientId in recipients {
                await MessagePushClient.send(
                    recipientId: recipientId,
                    messageId: messageId,
                    roomId: roomId,
                    senderId: senderId,
                    senderNickname: pushNickname,
                    messageType: AppGroupStorage.emergencyNudgeType,
                    content: content,
                    imageURL: nil,
                    roomDisplayTitle: roomTitle
                )
            }

            return .sent
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private static func insertEmergencyAlert(
        roomId: UUID,
        senderId: String,
        messageId: UUID,
        content: String
    ) async throws {
        let endpoint = SignalSupabaseConfig.url
            .appendingPathComponent("rest/v1/messages")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SignalSupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SignalSupabaseConfig.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let payload = EmergencyInsertPayload(
            id: messageId,
            roomId: roomId,
            senderId: senderId,
            type: AppGroupStorage.emergencyNudgeType,
            content: content
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HeartWidgetServiceError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw HeartWidgetServiceError.server(body)
        }
    }

    private static func insertHeartNudge(
        roomId: UUID,
        senderId: String,
        messageId: UUID,
        content: String
    ) async throws {
        let endpoint = SignalSupabaseConfig.url
            .appendingPathComponent("rest/v1/messages")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SignalSupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SignalSupabaseConfig.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let payload = HeartNudgeInsertPayload(
            id: messageId,
            roomId: roomId,
            senderId: senderId,
            type: "nudge",
            content: content
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HeartWidgetServiceError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw HeartWidgetServiceError.server(body)
        }
    }
}

private enum HeartWidgetServiceError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "서버 응답을 확인할 수 없습니다."
        case .server(let message):
            return message
        }
    }
}

private struct HeartNudgeInsertPayload: Encodable {
    let id: UUID
    let roomId: UUID
    let senderId: String
    let type: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case senderId = "sender_id"
        case type
        case content
        case mediaUrl = "media_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(roomId, forKey: .roomId)
        try container.encode(senderId, forKey: .senderId)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encodeNil(forKey: .mediaUrl)
    }
}

private struct EmergencyInsertPayload: Encodable {
    let id: UUID
    let roomId: UUID
    let senderId: String
    let type: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case senderId = "sender_id"
        case type
        case content
        case mediaUrl = "media_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(roomId, forKey: .roomId)
        try container.encode(senderId, forKey: .senderId)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encodeNil(forKey: .mediaUrl)
    }
}
