//
//  NudgeService.swift
//  SignalApp + SignalWidgetExtension
//

import Foundation

enum NudgeSendResult: Equatable {
    case sent
    case cooldown(remainingSeconds: Int)
    case notConfigured
    case failed(String)
}

enum NudgeService {
    private static let nudgeContent = "⚡️ 넛지!"

    static func sendNudgeIfAllowed() async -> NudgeSendResult {
        guard AppGroupStorage.isSessionConfigured,
              let roomId = AppGroupStorage.resolvedRoomUUID,
              let senderId = AppGroupStorage.currentUserId else {
            return .notConfigured
        }

        if AppGroupStorage.isOnCooldown {
            return .cooldown(remainingSeconds: AppGroupStorage.cooldownRemainingSeconds)
        }

        guard AppGroupStorage.canConsumeHeartQuotaLocally() else {
            return .failed("오늘 무료 이용 횟수를 모두 사용했어요.")
        }

        do {
            try await insertNudgeMessage(roomId: roomId, senderId: senderId)
            AppGroupStorage.consumeHeartQuotaLocallyIfNeeded()
            AppGroupStorage.lastNudgeSentAt = Date()
            return .sent
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Supabase PostgREST — 위젯 확장에서 URLSession으로 직접 INSERT (media_url = null).
    private static func insertNudgeMessage(roomId: UUID, senderId: String) async throws {
        let endpoint = SignalSupabaseConfig.url
            .appendingPathComponent("rest/v1/messages")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SignalSupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SignalSupabaseConfig.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let payload = NudgeInsertPayload(
            roomId: roomId,
            senderId: senderId,
            type: "nudge",
            content: nudgeContent
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NudgeServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw NudgeServiceError.server(body)
        }
    }
}

private enum NudgeServiceError: LocalizedError {
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

private struct NudgeInsertPayload: Encodable {
    let roomId: UUID
    let senderId: String
    let type: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case senderId = "sender_id"
        case type
        case content
        case mediaUrl = "media_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(roomId, forKey: .roomId)
        try container.encode(senderId, forKey: .senderId)
        try container.encode(type, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encodeNil(forKey: .mediaUrl)
    }
}
