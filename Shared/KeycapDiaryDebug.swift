//
//  KeycapDiaryDebug.swift
//  SignalApp + SignalWidgetExtension
//

import Foundation

/// 키캡 다이어리 a/c 집계 — Xcode 콘솔에서 `KeycapDiary` 로 필터.
enum KeycapDiaryDebug {
    static var isLoggingEnabled = true

    /// 앱 `MediaMessage`와 분리 — Shared·위젯 타겟에서도 컴파일 가능.
    struct MessageRow {
        let type: String
        let senderId: String
        let senderNickname: String?
        let content: String?
        let createdAt: Date
    }

    private static let prefix = "📊 [KeycapDiary]"

    static func log(_ message: String) {
        guard isLoggingEnabled else { return }
        print("\(prefix) \(message)")
    }

    // MARK: - Send path

    static func logKeycapInsert(
        source: String,
        roomId: UUID,
        senderId: String,
        content: String,
        messageId: UUID? = nil,
        symbolKeyHint: String? = nil
    ) {
        let parsed = AppGroupStorage.keycapDiarySymbolKey(fromNudgeContent: content)
        let alt = AppGroupStorage.keycapSymbolKey(fromNudgeContent: content)
        let idLine = messageId.map { " id=\($0.uuidString)" } ?? ""
        let hint = symbolKeyHint.map { " symbolKeyHint=\($0)" } ?? ""
        log(
            """
            INSERT source=\(source)\(idLine) room=\(roomId.uuidString) \
            sender_id=\(senderId) canonical=\(DeviceUserId.canonical(senderId))\(hint) \
            content=\(contentQuoted(content)) \
            diaryKey=\(parsed ?? "nil") chatKey=\(alt ?? "nil")
            """
        )
    }

    // MARK: - Month load

    static func logMonthFetch(
        roomId: UUID,
        month: Date,
        rangeStart: Date,
        rangeEnd: Date,
        myUserId: String,
        statColumns: [(userId: String, displayName: String)],
        messages: [MessageRow]
    ) {
        let nudges = messages.filter { $0.type == "nudge" }
        let diaryEligible = nudges.filter {
            AppGroupStorage.keycapDiarySymbolKey(fromNudgeContent: $0.content) != nil
        }
        log(
            """
            loadMonth room=\(roomId.uuidString) month=\(monthLabel(month)) \
            rangeLocal=[\(isoLocal(rangeStart)) .. \(isoLocal(rangeEnd))) \
            totalRows=\(messages.count) nudgeRows=\(nudges.count) diaryEligibleNudges=\(diaryEligible.count) \
            myUserId=\(myUserId) canonical=\(DeviceUserId.canonical(myUserId))
            """
        )
        if messages.count >= 1000, messages.count % 1000 == 0 {
            log("loadMonth hint: row count is a multiple of 1000 — if counts look wrong, check pagination")
        }
        log("statColumns(count=\(statColumns.count)): \(statColumns.map { columnLine($0.userId, $0.displayName) }.joined(separator: " | "))")

        let senderIds = Set(nudges.map(\.senderId))
        log("distinct nudge sender_id in month: \(senderIds.sorted().map { "\($0)(canon:\(DeviceUserId.canonical($0)))" }.joined(separator: ", "))")

        for (index, nudge) in nudges.prefix(25).enumerated() {
            logNudgeRow(index: index, nudge: nudge, context: "monthSample")
        }
        if nudges.count > 25 {
            log("… \(nudges.count - 25) more nudge rows omitted from sample")
        }
    }

    // MARK: - Day aggregation

    static func logDayAggregation(
        day: Date,
        myUserId: String,
        myDisplayName: String,
        partnerDisplayName: String,
        statColumns: [(userId: String, displayName: String)],
        nudges: [MessageRow],
        bySender: [String: [String: Int]],
        resolvedColumns: [(userId: String, displayName: String, resolvedFrom: String)],
        matrixPreview: [(emoji: String, key: String, counts: [Int])]
    ) {
        log("--- day=\(dayLabel(day)) nudgesOnDay=\(nudges.count) ---")

        if nudges.isEmpty {
            log("no nudge rows on this day (check month fetch range / timezone / type filter)")
        }

        for (index, nudge) in nudges.enumerated() {
            let diaryKey = AppGroupStorage.keycapDiarySymbolKey(fromNudgeContent: nudge.content)
            if let diaryKey {
                log(
                    """
                    nudge[\(index)] OK type=\(nudge.type) sender_id=\(nudge.senderId) \
                    nick=\(nudge.senderNickname ?? "nil") diaryKey=\(diaryKey) content=\(contentQuoted(nudge.content))
                    """
                )
            } else {
                let chatKey = AppGroupStorage.keycapSymbolKey(fromNudgeContent: nudge.content)
                let bipbi = nudge.content.map { BipbiPagerEasterEgg.isBipbiNudgeContent($0) } ?? false
                log(
                    """
                    nudge[\(index)] SKIP diaryKey=nil bipbi=\(bipbi) chatKey=\(chatKey ?? "nil") \
                    sender_id=\(nudge.senderId) content=\(contentQuoted(nudge.content))
                    """
                )
            }
        }

        log("bySender buckets: \(bySenderDescription(bySender))")

        for column in resolvedColumns {
            log(
                """
                column «\(column.displayName)» memberUserId=\(column.userId) \
                resolvedSenderKey=\(column.resolvedFrom) \
                matchesMember=\(DeviceUserId.matches(column.userId, column.resolvedFrom))
                """
            )
        }

        for row in matrixPreview.prefix(5) {
            log("matrix row \(row.emoji) key=\(row.key) counts=\(row.counts)")
        }
        if matrixPreview.count > 5 {
            log("… \(matrixPreview.count - 5) more matrix rows")
        }

        log("myUserId=\(myUserId) myDisplayName=\(myDisplayName) partnerDisplayName=\(partnerDisplayName)")
    }

    static func logResolveSender(
        columnDisplayName: String,
        columnUserId: String,
        outcome: String,
        matchedSenderId: String?
    ) {
        log(
            """
            resolveSender column=\(columnDisplayName) memberUserId=\(columnUserId) \
            → \(outcome)\(matchedSenderId.map { " senderKey=\($0)" } ?? "")
            """
        )
    }

    // MARK: - Helpers

    private static func contentQuoted(_ content: String?) -> String {
        guard let content else { return "nil" }
        if content.count > 120 {
            return "\"\(content.prefix(120))…\" (len=\(content.count))"
        }
        return "\"\(content)\""
    }

    private static func bySenderDescription(_ bySender: [String: [String: Int]]) -> String {
        if bySender.isEmpty { return "{}" }
        return bySender
            .sorted { $0.key < $1.key }
            .map { sender, bucket in
                let inner = bucket.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ",")
                return "\(sender)={\(inner)}"
            }
            .joined(separator: " ")
    }

    private static func columnLine(_ userId: String, _ name: String) -> String {
        "«\(name)» userId=\(userId)"
    }

    private static func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }

    private static func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func dayLabelForLog(_ date: Date) -> String {
        dayLabel(date)
    }

    private static func isoLocal(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    private static func logNudgeRow(index: Int, nudge: MessageRow, context: String) {
        let diaryKey = AppGroupStorage.keycapDiarySymbolKey(fromNudgeContent: nudge.content)
        log(
            """
            \(context)[\(index)] created=\(isoLocal(nudge.createdAt)) type=\(nudge.type) \
            sender_id=\(nudge.senderId) diaryKey=\(diaryKey ?? "nil") content=\(contentQuoted(nudge.content))
            """
        )
    }
}
