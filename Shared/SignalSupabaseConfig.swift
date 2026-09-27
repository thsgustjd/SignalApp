//
//  SignalSupabaseConfig.swift
//  SignalApp + SignalWidgetExtension
//

import Foundation

enum SignalSupabaseConfig {
    static let url = URL(string: "https://qxwnasdzmoxhvishdbav.supabase.co")!
    static let publishableKey = "sb_publishable_rFJs9D2tjzlCJhub3KFxvQ_CrtM1E_q"
    /// Supabase Storage 버킷 ID (대시보드 이름과 **정확히** 동일해야 함. 보통 `media`)
    static let mediaStorageBucket = "media"
    static let messagePushFunctionName = "send-message-push"
    /// @deprecated `send-message-push` 사용
    static let drawingPushFunctionName = "send-drawing-push"
}
