//
//  MessagePushClient.swift
//  SignalApp + SignalWidgetExtension
//

import Foundation

/// Edge Function `send-message-push` — Supabase SDK 없이 URLSession (위젯·앱 공통).
enum MessagePushClient {
    static func send(
        recipientId: String,
        messageId: UUID,
        roomId: UUID,
        senderId: String,
        senderNickname: String,
        messageType: String,
        content: String?,
        imageURL: String?,
        roomDisplayTitle: String? = nil
    ) async {
        guard !recipientId.isEmpty, recipientId != senderId else { return }

        let url = SignalSupabaseConfig.url
            .appendingPathComponent("functions/v1/\(SignalSupabaseConfig.messagePushFunctionName)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SignalSupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SignalSupabaseConfig.publishableKey)", forHTTPHeaderField: "Authorization")

        let body = Payload(
            recipientId: recipientId,
            messageId: messageId,
            roomId: roomId,
            senderId: senderId,
            senderNickname: senderNickname,
            messageType: messageType,
            content: content,
            imageURL: imageURL,
            roomDisplayTitle: roomDisplayTitle
        )

        print(
            """
            📤 [MessagePush] Edge Function type=\(messageType) \
            recipient_id=\(recipientId) \
            sender_id=\(senderId)
            (profiles.id must match recipient_id exactly — case/hyphens)
            """
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                print("❌ [MessagePush] invalid URLResponse (not HTTP)")
                return
            }
            logPushFunctionResponse(
                httpStatus: http.statusCode,
                messageType: messageType,
                messageId: messageId,
                data: data
            )
        } catch {
            print("❌ [MessagePush] network error — \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("   URLError code=\(urlError.code.rawValue) \(urlError.code)")
            }
        }
    }

    /// Edge Function JSON 응답을 파싱해 APNs 성공/스킵/실패를 콘솔에 구분해 출력합니다.
    private static func logPushFunctionResponse(
        httpStatus: Int,
        messageType: String,
        messageId: UUID,
        data: Data
    ) {
        let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8, \(data.count) bytes>"
        print(
            """
            📡 [MessagePush] HTTP \(httpStatus) type=\(messageType) \
            id=\(messageId.uuidString.prefix(8))… body=\(rawBody)
            """
        )

        let parsed = try? JSONDecoder().decode(PushFunctionResponse.self, from: data)

        if let parsed {
            if parsed.ok == true, parsed.sent == true {
                var detail = "APNs 발송 OK"
                if let status = parsed.apnsStatus { detail += " apns_status=\(status)" }
                if let apnsId = parsed.apnsId, !apnsId.isEmpty { detail += " apns_id=\(apnsId)" }
                print("✅ [MessagePush] \(detail)")
                return
            }

            if let apnsReason = parsed.apnsReason, !apnsReason.isEmpty {
                print("❌ [MessagePush] APNs 거부 — reason=\(apnsReason)\(apnsHint(for: apnsReason))")
                if let status = parsed.apnsStatus { print("   apns_status=\(status)") }
                if let detail = parsed.apnsDetail, !detail.isEmpty { print("   apns_detail=\(detail)") }
                return
            }

            if let reason = parsed.reason, !reason.isEmpty {
                if reason == "no_apns_token" {
                    print("🔴 [MessagePush] no_apns_token — recipient_id=\(parsed.recipientId ?? "?")")
                    print("   profiles.id lookup column=\(parsed.profilesLookupColumn ?? "id")")
                    if let variants = parsed.profilesLookupVariants, !variants.isEmpty {
                        print("   tried ids: \(variants.joined(separator: ", "))")
                    }
                    print("   profile_row_found=\(parsed.profileRowFound.map { String($0) } ?? "?") matched=\(parsed.matchedProfileId ?? "nil")")
                    if let hint = parsed.hint { print("   hint: \(hint)") }
                }
                print("⚠️ [MessagePush] push 미발송 — reason=\(reason)\(serverReasonHint(reason))")
                return
            }

            if let error = parsed.error, !error.isEmpty {
                print("❌ [MessagePush] Edge Function error — \(error)")
                return
            }

            if parsed.ok == false {
                print("❌ [MessagePush] ok=false (sent=\(parsed.sent.map { String($0) } ?? "nil"))")
                return
            }
        }

        if (200 ... 299).contains(httpStatus) {
            print("✅ [MessagePush] HTTP 2xx (응답 JSON 파싱 불가 — body 확인)")
        } else {
            print("❌ [MessagePush] HTTP \(httpStatus) — Edge Function 실패")
        }
    }

    private static func apnsHint(for reason: String) -> String {
        switch reason {
        case "BadDeviceToken":
            return " (토큰 무효·만료 — profiles.apns_token 재등록, sandbox/production 일치 확인)"
        case "DeviceTokenNotForTopic":
            return " (APNS_BUNDLE_ID / 앱 번들 ID 불일치)"
        case "MissingProviderToken", "InvalidProviderToken":
            return " (APNS_KEY_ID·TEAM_ID·PRIVATE_KEY 시크릿 확인)"
        case "ExpiredProviderToken":
            return " (APNS JWT 만료 — 서버 시계·키 재발급)"
        case "TooManyRequests":
            return " (APNs rate limit)"
        case "PayloadTooLarge":
            return " (페이로드 크기 초과)"
        default:
            return ""
        }
    }

    private static func serverReasonHint(_ reason: String) -> String {
        switch reason {
        case "no_apns_token":
            return " — 수신 기기에서 앱 실행·알림 허용·🟢 APNs SUCCESS 로그 확인"
        case "no_recipient_id":
            return " (recipient_id·room 매칭 실패)"
        case "apns_failed":
            return " (APNs HTTP 오류 — apns_reason 확인)"
        default:
            return ""
        }
    }

    static func partnerUserId(roomId: UUID, senderId: String) async -> String? {
        let ids = await recipientUserIds(roomId: roomId, senderId: senderId)
        return ids.first
    }

    static func recipientUserIds(roomId: UUID, senderId: String) async -> [String] {
        if let fromMembers = await memberRecipientUserIds(roomId: roomId, senderId: senderId), !fromMembers.isEmpty {
            return fromMembers
        }
        return await roomRecipientUserIds(roomId: roomId, senderId: senderId)
    }

    private static func memberRecipientUserIds(roomId: UUID, senderId: String) async -> [String]? {
        var components = URLComponents(
            url: SignalSupabaseConfig.url.appendingPathComponent("rest/v1/room_members"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "room_id", value: "eq.\(roomId.uuidString)"),
            URLQueryItem(name: "select", value: "user_id")
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue(SignalSupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SignalSupabaseConfig.publishableKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return nil
            }
            let rows = try JSONDecoder().decode([RoomMemberUserRow].self, from: data)
            let filtered = rows.map(\.userId).filter { !DeviceUserId.matches($0, senderId) }
            return filtered.isEmpty ? nil : filtered
        } catch {
            return nil
        }
    }

    private static func roomRecipientUserIds(roomId: UUID, senderId: String) async -> [String] {
        var components = URLComponents(
            url: SignalSupabaseConfig.url.appendingPathComponent("rest/v1/rooms"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(roomId.uuidString)"),
            URLQueryItem(name: "select", value: "user1_id,user2_id")
        ]
        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue(SignalSupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SignalSupabaseConfig.publishableKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return []
            }
            let rows = try JSONDecoder().decode([RoomUserIdsRow].self, from: data)
            guard let row = rows.first else { return [] }
            if DeviceUserId.matches(row.user1Id, senderId) {
                if let user2 = row.user2Id, !user2.isEmpty { return [user2] }
                return []
            }
            if let user2 = row.user2Id, DeviceUserId.matches(user2, senderId) {
                return [row.user1Id]
            }
            var ids: [String] = []
            if !row.user1Id.isEmpty, !DeviceUserId.matches(row.user1Id, senderId) { ids.append(row.user1Id) }
            if let user2 = row.user2Id, !user2.isEmpty, !DeviceUserId.matches(user2, senderId) { ids.append(user2) }
            return ids
        } catch {
            print("❌ [MessagePushClient] room lookup \(error.localizedDescription)")
            return []
        }
    }

    private struct RoomMemberUserRow: Decodable {
        let userId: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
        }
    }

    private struct PushFunctionResponse: Decodable {
        let ok: Bool?
        let sent: Bool?
        let reason: String?
        let error: String?
        let recipientId: String?
        let profilesLookupColumn: String?
        let profilesLookupVariants: [String]?
        let profileRowFound: Bool?
        let matchedProfileId: String?
        let hint: String?
        let apnsStatus: Int?
        let apnsReason: String?
        let apnsDetail: String?
        let apnsId: String?

        enum CodingKeys: String, CodingKey {
            case ok, sent, reason, error, hint
            case recipientId = "recipient_id"
            case profilesLookupColumn = "profiles_lookup_column"
            case profilesLookupVariants = "profiles_lookup_variants"
            case profileRowFound = "profile_row_found"
            case matchedProfileId = "matched_profile_id"
            case apnsStatus = "apns_status"
            case apnsReason = "apns_reason"
            case apnsDetail = "apns_detail"
            case apnsId = "apns_id"
        }
    }

    private struct Payload: Encodable {
        let recipientId: String
        let messageId: UUID
        let roomId: UUID
        let senderId: String
        let senderNickname: String
        let messageType: String
        let content: String?
        let imageURL: String?
        let roomDisplayTitle: String?

        enum CodingKeys: String, CodingKey {
            case recipientId = "recipient_id"
            case messageId = "message_id"
            case roomId = "room_id"
            case senderId = "sender_id"
            case senderNickname = "sender_nickname"
            case messageType = "message_type"
            case content
            case imageURL = "image_url"
            case roomDisplayTitle = "room_display_title"
        }
    }

    private struct RoomUserIdsRow: Decodable {
        let user1Id: String
        let user2Id: String?

        enum CodingKeys: String, CodingKey {
            case user1Id = "user1_id"
            case user2Id = "user2_id"
        }
    }
}
