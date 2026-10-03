//
//  ChatRoomBarTitleFormatting.swift
//  SignalApp
//

import Foundation

enum ChatRoomBarTitleFormatting {
    /// 참가자 이름 나열·사용자 지정 제목 공통 — 5자 미만은 전부, 5자 이상이면 앞 5자(또는 4자) + `...`
    static func truncatedForTopBar(_ full: String) -> String {
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "채팅방" }
        if trimmed.count < 5 { return trimmed }
        let head = trimmed.count == 5 ? 4 : 5
        return String(trimmed.prefix(head)) + "..."
    }
}
