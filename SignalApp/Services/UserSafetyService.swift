//
//  UserSafetyService.swift
//  SignalApp
//

import Foundation

enum UserSafetyService {
    enum ReportCategory: String, CaseIterable, Identifiable {
        case spam
        case harassment
        case illegal
        case other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .spam: return "스팸"
            case .harassment: return "괴롭힘·혐오"
            case .illegal: return "음란·불법"
            case .other: return "기타"
            }
        }
    }

    struct ReportDraft {
        let roomId: UUID
        let reportedUserId: String?
        let messageId: UUID?
        let category: ReportCategory
        let note: String
        let reporterNickname: String?
    }

    private struct ContentReportInsert: Encodable {
        let reporterUserId: String
        let reporterNickname: String?
        let roomId: UUID
        let reportedUserId: String?
        let messageId: UUID?
        let category: String
        let note: String?

        enum CodingKeys: String, CodingKey {
            case reporterUserId = "reporter_user_id"
            case reporterNickname = "reporter_nickname"
            case roomId = "room_id"
            case reportedUserId = "reported_user_id"
            case messageId = "message_id"
            case category
            case note
        }
    }

    @MainActor
    static func submitReport(_ draft: ReportDraft) async throws {
        let manager = SupabaseManager.shared
        guard await manager.prepareProfileDatabaseAccessForSafety() else {
            throw UserSafetyError.notAuthenticated
        }

        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = ContentReportInsert(
            reporterUserId: manager.currentUserId,
            reporterNickname: draft.reporterNickname,
            roomId: draft.roomId,
            reportedUserId: draft.reportedUserId,
            messageId: draft.messageId,
            category: draft.category.rawValue,
            note: note.isEmpty ? nil : note
        )

        try await manager.client
            .from("content_reports")
            .insert(payload)
            .execute()
    }

    @MainActor
    static func deleteAllMyData() async throws {
        let manager = SupabaseManager.shared
        guard await manager.prepareProfileDatabaseAccessForSafety() else {
            throw UserSafetyError.notAuthenticated
        }

        struct DeleteParams: Encodable {
            let pUserId: String

            enum CodingKeys: String, CodingKey {
                case pUserId = "p_user_id"
            }
        }

        try await manager.client
            .rpc("delete_my_account_data", params: DeleteParams(pUserId: manager.currentUserId))
            .execute()

        manager.wipeAllLocalUserDataAfterServerDelete()
    }
}

enum UserSafetyError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "연결을 확인한 뒤 다시 시도해 주세요."
        }
    }
}
