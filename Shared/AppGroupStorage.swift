//
//  AppGroupStorage.swift
//  SignalApp + SignalWidgetExtension
//

import Foundation

enum AppGroupStorage {
    /// `AppGroupConfig.suiteName`과 동일 (하위 호환).
    static var suiteName: String { AppGroupConfig.suiteName }

    private enum Keys {
        static let currentRoomId = "currentRoomId"
        static let currentUserId = "currentUserId"
        static let roomId = "roomId"
        static let userId = "userId"
        static let lastNudgeSentAt = "lastNudgeSentAt"
        static let lastWidgetHeartSentAt = "lastWidgetHeartSentAt"
        static let widgetHeartTapCount = "widgetHeartTapCount"
        static let keycapCustomMessages = "keycapCustomMessages"
        static let keycapCustomTitles = "keycapCustomTitles"
        static let keycapCustomEmojis = "keycapCustomEmojis"
        static let isSignalDNDActive = "isSignalDNDActive"
        static let emergencyTapCount = "emergencyTapCount"
        static let emergencyLastTapAt = "emergencyLastTapAt"
        static let emergencyArmedAt = "emergencyArmedAt"
        static let lastEmergencySentAt = "lastEmergencySentAt"
        static let widgetTargetRoomId = "widgetTargetRoomId"
        static let currentSenderNickname = "currentSenderNickname"
        static let pushRoomDisplayTitles = "pushRoomDisplayTitlesByRoomId"
    }

    static let emergencyNudgeType = "emergency"
    static let emergencyDisplayText = "비상"
    static let emergencyRequiredTapCount = 5
    static let emergencyTapSequenceWindow: TimeInterval = 2.0
    static let emergencyArmTimeout: TimeInterval = 5.0
    static let emergencyLongPressHoldAfterArm: TimeInterval = 0.55
    static let emergencySendCooldownSeconds: TimeInterval = 60

    static let defaultKeycapMessages: [String: String] = [
        "heart": "사랑해",
        "pleading": "보고싶어",
        "tongue": "메롱",
        "question": "뭐해?",
        "angry": "그만해라",
        "sleep": "잘자",
        "grin": "굿모닝!",
        "clover": "흥!",
        "pencil": "연락 봐줘",
        "doc": "전화 해줘",
        "tired": "피곤해",
        "hungry": "배고파",
        "cold": "심심해",
        "hot": "퇴근",
        "play": "놀자"
    ]

    static let keycapNudgeTypeOrder: [String] = [
        "heart", "pleading", "tongue", "question", "play", "angry", "sleep", "grin", "clover",
        "pencil", "hungry", "tired", "cold", "doc", "hot"
    ]

    /// 1~15번 중 **13~15번** (cold, doc, hot) — 이모지·표시 이름 사용자 커스텀.
    static var keycapUserCustomizableTypes: [String] {
        guard keycapNudgeTypeOrder.count >= 15 else { return [] }
        return Array(keycapNudgeTypeOrder.suffix(3))
    }

    static func isUserCustomizableKeycap(_ type: String) -> Bool {
        keycapUserCustomizableTypes.contains(normalizedKeycapType(type))
    }

    private static let removedKeycapTypes: Set<String> = ["star", "meal", "yummy", "camera", "sleepy"]

    /// 레거시 nudgeType → 현재 키캡 키 (제거된 타입은 통계에서 제외).
    private static let legacyKeycapTypeMap: [String: String] = [
        "moon": "sleep",
        "sun": "grin",
        "meal": "hungry",
        "yummy": "hungry"
    ]

    /// 예전 기본 문구 → 키 (통계·역매칭용)
    private static let legacyDefaultMessageToKey: [String: String] = [
        "공부중 화이팅!": "pencil",
        "일하는중 화이팅!": "doc",
        "피곤해?": "tired",
        "좋은 하루 보내": "clover",
        "추워": "cold",
        "더워": "hot",
    ]

    static func normalizedKeycapType(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return legacyKeycapTypeMap[trimmed] ?? trimmed
    }

    static func isActiveKeycapType(_ type: String) -> Bool {
        keycapNudgeTypeOrder.contains(type)
    }

    /// 이모지 각인 키캡이면 이모지 문자열, SF Symbol 키캡이면 nil.
    static func keycapEmoji(for nudgeType: String) -> String? {
        let type = normalizedKeycapType(nudgeType)
        if isUserCustomizableKeycap(type),
           let custom = loadCustomKeycapEmojis()[type]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        return defaultKeycapEmoji(for: type)
    }

    static func defaultKeycapEmoji(for type: String) -> String? {
        switch normalizedKeycapType(type) {
        case "pleading": return "🥺"
        case "tongue": return "😝"
        case "angry": return "😠"
        case "sleep": return "😴"
        case "grin": return "😁"
        case "clover": return "😤"
        case "pencil": return "😑"
        case "doc": return "📞"
        case "tired": return "🥱"
        case "hungry": return "😩"
        case "cold": return "😕"
        case "hot": return "🤗"
        case "play": return "😆"
        case "question": return "👀"
        default: return nil
        }
    }

    /// 설정·채팅 그리드용 표시 이름 (13~15번 cold·doc·hot 은 사용자 저장값 우선).
    static func displayTitle(for type: String) -> String {
        let key = normalizedKeycapType(type)
        if isUserCustomizableKeycap(key),
           let custom = loadCustomKeycapTitles()[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        return defaultDisplayTitle(for: key)
    }

    static func defaultDisplayTitle(for type: String) -> String {
        switch normalizedKeycapType(type) {
        case "heart": return "사랑해 키캡"
        case "pleading": return "보고싶어 키캡"
        case "tongue": return "메롱 키캡"
        case "question": return "뭐해 키캡"
        case "play": return "놀자 키캡"
        case "angry": return "그만해라 키캡"
        case "sleep": return "잘자 키캡"
        case "grin": return "굿모닝 키캡"
        case "clover": return "흥! 키캡"
        case "pencil": return "연락 봐줘"
        case "doc": return "전화 해줘"
        case "tired": return "피곤해"
        case "hungry": return "배고파 키캡"
        case "cold": return "심심해 키캡"
        case "hot": return "퇴근 키캡"
        default: return type
        }
    }

    static func sanitizeSingleEmojiInput(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        return String(first)
    }

    /// 위젯 전송 Intent 등에서 사용 — 커스텀 저장값 우선, 없으면 기본 문구.
    static func getMessage(for nudgeType: String) -> String {
        getCustomMessage(for: nudgeType)
    }

    static func getCustomMessage(for nudgeType: String) -> String {
        effectiveKeycapMessage(for: nudgeType, saved: loadCustomKeycapMessages())
    }

    /// 예전 앱 기본 문구 — 저장값이 이 텍스트면 새 기본값으로 취급.
    private static let supersededDefaultMessageTexts: [String: Set<String>] = [
        "pencil": ["공부중 화이팅!"],
        "doc": ["일하는중 화이팅!"],
        "tired": ["피곤해?"],
        "clover": ["좋은 하루 보내"],
    ]

    private static func effectiveKeycapMessage(for key: String, saved: [String: String]) -> String {
        let fallback = defaultKeycapMessages[key]
            ?? defaultKeycapMessages["heart"]
            ?? "사랑해"
        guard let custom = saved[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty else {
            return fallback
        }
        if supersededDefaultMessageTexts[key]?.contains(custom) == true {
            return fallback
        }
        return custom
    }

    /// 설정 화면용: 저장값이 없으면 기본 문구로 채움.
    static func keycapMessagesForEditing() -> [String: String] {
        let saved = loadCustomKeycapMessages()
        var merged = defaultKeycapMessages
        for key in keycapNudgeTypeOrder {
            merged[key] = effectiveKeycapMessage(for: key, saved: saved)
        }
        return merged
    }

    static func saveKeycapMessages(_ messages: [String: String]) {
        guard let defaults else { return }
        var payload: [String: String] = [:]
        for key in keycapNudgeTypeOrder {
            let trimmed = messages[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                payload[key] = trimmed
            }
        }
        if payload.isEmpty {
            defaults.removeObject(forKey: Keys.keycapCustomMessages)
        } else if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: Keys.keycapCustomMessages)
        }
        flush(defaults)
    }

    static func resetKeycapMessagesToDefaults() {
        guard let defaults else { return }
        defaults.removeObject(forKey: Keys.keycapCustomMessages)
        flush(defaults)
    }

    static func keycapTitlesForEditing() -> [String: String] {
        let saved = loadCustomKeycapTitles()
        var merged: [String: String] = [:]
        for key in keycapUserCustomizableTypes {
            merged[key] = saved[key] ?? defaultDisplayTitle(for: key)
        }
        return merged
    }

    static func keycapEmojisForEditing() -> [String: String] {
        let saved = loadCustomKeycapEmojis()
        var merged: [String: String] = [:]
        for key in keycapUserCustomizableTypes {
            merged[key] = saved[key] ?? defaultKeycapEmoji(for: key) ?? "⌨️"
        }
        return merged
    }

    static func saveKeycapAppearances(titles: [String: String], emojis: [String: String]) {
        guard let defaults else { return }

        var titlePayload: [String: String] = [:]
        var emojiPayload: [String: String] = [:]

        for key in keycapUserCustomizableTypes {
            let titleTrim = titles[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !titleTrim.isEmpty, titleTrim != defaultDisplayTitle(for: key) {
                titlePayload[key] = titleTrim
            }

            let emojiTrim = sanitizeSingleEmojiInput(emojis[key] ?? "")
            let defaultEmoji = defaultKeycapEmoji(for: key) ?? ""
            if !emojiTrim.isEmpty, emojiTrim != defaultEmoji {
                emojiPayload[key] = emojiTrim
            }
        }

        if titlePayload.isEmpty {
            defaults.removeObject(forKey: Keys.keycapCustomTitles)
        } else if let data = try? JSONEncoder().encode(titlePayload) {
            defaults.set(data, forKey: Keys.keycapCustomTitles)
        }

        if emojiPayload.isEmpty {
            defaults.removeObject(forKey: Keys.keycapCustomEmojis)
        } else if let data = try? JSONEncoder().encode(emojiPayload) {
            defaults.set(data, forKey: Keys.keycapCustomEmojis)
        }

        flush(defaults)
    }

    static func resetKeycapAppearance(for type: String) {
        guard isUserCustomizableKeycap(type), let defaults else { return }
        let key = normalizedKeycapType(type)

        var titles = loadCustomKeycapTitles()
        titles.removeValue(forKey: key)
        if titles.isEmpty {
            defaults.removeObject(forKey: Keys.keycapCustomTitles)
        } else if let data = try? JSONEncoder().encode(titles) {
            defaults.set(data, forKey: Keys.keycapCustomTitles)
        }

        var emojis = loadCustomKeycapEmojis()
        emojis.removeValue(forKey: key)
        if emojis.isEmpty {
            defaults.removeObject(forKey: Keys.keycapCustomEmojis)
        } else if let data = try? JSONEncoder().encode(emojis) {
            defaults.set(data, forKey: Keys.keycapCustomEmojis)
        }

        flush(defaults)
    }

    private static func loadCustomKeycapTitles() -> [String: String] {
        loadStringDictionary(forKey: Keys.keycapCustomTitles)
    }

    private static func loadCustomKeycapEmojis() -> [String: String] {
        loadStringDictionary(forKey: Keys.keycapCustomEmojis)
    }

    private static func loadStringDictionary(forKey key: String) -> [String: String] {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func loadCustomKeycapMessages() -> [String: String] {
        guard let defaults,
              let data = defaults.data(forKey: Keys.keycapCustomMessages),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    /// 키캡 1회 전송 INSERT용 — `heart|사랑해` (다이어리·표시·역매칭).
    static func storedContent(forKeycapNudge symbolKey: String, messageText: String) -> String {
        let key = normalizedKeycapType(symbolKey)
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(key)|\(text)"
    }

    /// INSERT 직전 — `symbolKey|문구` 포맷 보장 (레거시 `❤️` 단독 저장 방지).
    static func canonicalKeycapNudgeInsertContent(_ raw: String, symbolKey: String? = nil) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            let fallbackKey = resolvedActiveSymbolKey(symbolKey) ?? "heart"
            return storedContent(forKeycapNudge: fallbackKey, messageText: getMessage(for: fallbackKey))
        }
        if BipbiPagerEasterEgg.isBipbiNudgeContent(trimmed) { return trimmed }

        if let symbolKey, let key = resolvedActiveSymbolKey(symbolKey) {
            let text = messageTextForKeycapInsert(raw: trimmed, symbolKey: key)
            return storedContent(forKeycapNudge: key, messageText: text)
        }

        if let pipe = trimmed.firstIndex(of: "|") {
            let key = normalizedKeycapType(String(trimmed[..<pipe]))
            if isActiveKeycapType(key) {
                let suffix = String(trimmed[trimmed.index(after: pipe)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let text = suffix.isEmpty ? getMessage(for: key) : suffix
                return storedContent(forKeycapNudge: key, messageText: text)
            }
        }

        if let inferred = keycapDiarySymbolKey(fromNudgeContent: trimmed)
            ?? keycapSymbolKeyMatchingBareEmoji(trimmed) {
            let text = messageTextForKeycapInsert(raw: trimmed, symbolKey: inferred)
            return storedContent(forKeycapNudge: inferred, messageText: text)
        }

        return storedContent(forKeycapNudge: "heart", messageText: trimmed)
    }

    private static func resolvedActiveSymbolKey(_ symbolKey: String?) -> String? {
        guard let symbolKey else { return nil }
        let key = normalizedKeycapType(symbolKey)
        return isActiveKeycapType(key) ? key : nil
    }

    private static func messageTextForKeycapInsert(raw: String, symbolKey: String) -> String {
        let key = normalizedKeycapType(symbolKey)
        if keycapSymbolKeyMatchingBareEmoji(raw) == key {
            return getMessage(for: key)
        }
        if defaultKeycapMessages[key] == raw || getCustomMessage(for: key) == raw {
            return raw
        }
        if let pipe = raw.firstIndex(of: "|") {
            let suffix = String(raw[raw.index(after: pipe)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !suffix.isEmpty { return suffix }
        }
        return raw.isEmpty ? getMessage(for: key) : raw
    }

    /// 이모지 비교 — variation selector( FE0F )·공백 차이 무시.
    static func keycapEmojiMatchToken(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .filter { $0.value != 0xFE0F }
            .map { String($0) }
            .joined()
    }

    private static func keycapEmojisMatch(_ lhs: String, _ rhs: String) -> Bool {
        keycapEmojiMatchToken(lhs) == keycapEmojiMatchToken(rhs)
    }

    /// 레거시 DB — `content`가 키캡 이모지(`❤️`, `🥺` 등)만 있는 경우.
    static func keycapSymbolKeyMatchingBareEmoji(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for key in keycapNudgeTypeOrder {
            if let emoji = keycapEmoji(for: key), keycapEmojisMatch(emoji, trimmed) { return key }
        }
        if keycapEmojisMatch(trimmed, keycapSymbolPresentation(for: "heart").emoji) { return "heart" }
        return nil
    }

    /// 다이어리 키캡 횟수 집계 대상 (`nudge` + 레거시 `emoji` 단독 이모지).
    static func isKeycapDiaryCountableMessage(type: String, content: String?) -> Bool {
        if type == emergencyNudgeType { return false }
        guard type == "nudge" || type == "emoji" else { return false }
        return keycapDiarySymbolKey(fromNudgeContent: content) != nil
    }

    /// 다이어리 집계용 — `heart|문구`·레거시 문구. 삐삐(`bipbi|`) 제외.
    static func keycapDiarySymbolKey(fromNudgeContent content: String?) -> String? {
        guard let raw = content?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if BipbiPagerEasterEgg.isBipbiNudgeContent(raw) { return nil }

        if let pipe = raw.firstIndex(of: "|") {
            let key = normalizedKeycapType(String(raw[..<pipe]))
            if isActiveKeycapType(key) { return key }
        }

        for key in keycapNudgeTypeOrder {
            if defaultKeycapMessages[key] == raw { return key }
            if getCustomMessage(for: key) == raw { return key }
        }
        if let legacy = legacyDefaultMessageToKey[raw] { return legacy }
        if let emojiKey = keycapSymbolKeyMatchingBareEmoji(raw) { return emojiKey }
        return keycapSymbolKey(fromNudgeContent: raw)
    }

    /// 넛지 `content`에서 키캡 심볼 키 추출 (`heart|문구`, 레거시 `star`, 문구 매칭).
    static func keycapSymbolKey(fromNudgeContent content: String?) -> String? {
        guard let raw = content?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if BipbiPagerEasterEgg.isBipbiNudgeContent(raw) { return nil }
        if let pipe = raw.firstIndex(of: "|") {
            let key = normalizedKeycapType(String(raw[..<pipe]))
            if isActiveKeycapType(key) { return key }
            if removedKeycapTypes.contains(key) { return nil }
        }
        let normalized = normalizedKeycapType(raw)
        if isActiveKeycapType(normalized) { return normalized }
        if removedKeycapTypes.contains(normalized) { return nil }
        for key in keycapNudgeTypeOrder {
            if getCustomMessage(for: key) == raw { return key }
            if defaultKeycapMessages[key] == raw { return key }
        }
        if legacyDefaultMessageToKey[raw] != nil {
            return legacyDefaultMessageToKey[raw]
        }
        for (legacy, mapped) in legacyKeycapTypeMap {
            if getCustomMessage(for: mapped) == raw || defaultKeycapMessages[mapped] == raw {
                return mapped
            }
            if legacy == raw { return mapped }
        }
        return nil
    }

    static func keycapDisplayText(fromNudgeContent content: String?) -> String {
        guard let raw = content?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "넛지"
        }
        if let bipbi = BipbiPagerEasterEgg.displayText(fromStoredContent: raw) {
            return bipbi
        }
        if let pipe = raw.firstIndex(of: "|") {
            let text = String(raw[raw.index(after: pipe)...])
            if !text.isEmpty { return text }
        }
        if keycapNudgeTypeOrder.contains(raw) {
            return getCustomMessage(for: raw)
        }
        return raw
    }

    static func keycapSymbolPresentation(for key: String) -> (emoji: String, title: String) {
        if key == emergencyNudgeType {
            return ("🚨", emergencyDisplayText)
        }
        let type = normalizedKeycapType(key)
        guard isActiveKeycapType(type) else { return ("⌨️", "키캡") }
        if let emoji = keycapEmoji(for: type) {
            return (emoji, displayTitle(for: type))
        }
        switch type {
        case "heart": return ("❤️", "사랑해")
        default: return ("⌨️", "키캡")
        }
    }

    private static func shortTitle(for type: String, fallback: String) -> String {
        switch type {
        case "pleading": return "보고싶어"
        case "tongue": return "메롱"
        case "angry": return "그만해라"
        case "sleep": return "잘자"
        case "grin": return "굿모닝"
        case "clover": return "흥!"
        case "tired": return "피곤해"
        case "hungry": return "배고파"
        case "cold": return "심심해"
        case "hot": return "퇴근"
        case "play": return "놀자"
        default: return fallback
        }
    }

    /// 잠금화면 🚫 방해금지 락 키캡 — 켜면 수신 알림·햅틱을 뮤트합니다.
    static var isSignalDNDActive: Bool {
        get { defaults?.bool(forKey: Keys.isSignalDNDActive) ?? false }
        set {
            guard let defaults else { return }
            defaults.set(newValue, forKey: Keys.isSignalDNDActive)
            flush(defaults)
        }
    }

    static func toggleSignalDNDActive() {
        isSignalDNDActive = !isSignalDNDActive
    }

    // MARK: - 🚨 비상 키캡 (5연타 → 길게 누르기)

    enum EmergencyInteractionPhase: Equatable {
        case counting(current: Int, required: Int)
        case armedWaitingLongPress
        case cooldown(remainingSeconds: Int)
    }

    static func resetEmergencyInteraction() {
        guard let defaults else { return }
        defaults.removeObject(forKey: Keys.emergencyTapCount)
        defaults.removeObject(forKey: Keys.emergencyLastTapAt)
        defaults.removeObject(forKey: Keys.emergencyArmedAt)
        flush(defaults)
    }

    static func emergencyInteractionPhase(now: Date = Date()) -> EmergencyInteractionPhase {
        if let last = lastEmergencySentAt,
           now.timeIntervalSince(last) < emergencySendCooldownSeconds {
            let remaining = Int(ceil(emergencySendCooldownSeconds - now.timeIntervalSince(last)))
            return .cooldown(remainingSeconds: max(1, remaining))
        }
        guard let defaults else { return .counting(current: 0, required: emergencyRequiredTapCount) }
        pruneExpiredEmergencyArm(now: now, defaults: defaults)
        pruneExpiredEmergencyTapSequence(now: now, defaults: defaults)

        if defaults.object(forKey: Keys.emergencyArmedAt) as? Date != nil {
            return .armedWaitingLongPress
        }

        let count = defaults.integer(forKey: Keys.emergencyTapCount)
        return .counting(current: count, required: emergencyRequiredTapCount)
    }

    /// 위젯 타임라인 — 연타 만료·무장·쿨다운 종료 시점에 UI 갱신.
    static func emergencyWidgetNextReloadDate(now: Date = Date()) -> Date? {
        guard let defaults else { return nil }
        if let last = lastEmergencySentAt,
           now.timeIntervalSince(last) < emergencySendCooldownSeconds {
            return last.addingTimeInterval(emergencySendCooldownSeconds)
        }
        if let armedAt = defaults.object(forKey: Keys.emergencyArmedAt) as? Date {
            return armedAt.addingTimeInterval(emergencyArmTimeout)
        }
        let count = defaults.integer(forKey: Keys.emergencyTapCount)
        guard count > 0,
              let lastTap = defaults.object(forKey: Keys.emergencyLastTapAt) as? Date else {
            return nil
        }
        return lastTap.addingTimeInterval(emergencyTapSequenceWindow)
    }

    /// 앱·위젯 공통 — 짧게 누를 때마다 호출 (전송 없음).
    @discardableResult
    static func recordEmergencyTap(now: Date = Date()) -> EmergencyInteractionPhase {
        guard let defaults else { return .counting(current: 0, required: emergencyRequiredTapCount) }
        if let last = lastEmergencySentAt,
           now.timeIntervalSince(last) < emergencySendCooldownSeconds {
            return emergencyInteractionPhase(now: now)
        }

        pruneExpiredEmergencyArm(now: now, defaults: defaults)
        pruneExpiredEmergencyTapSequence(now: now, defaults: defaults)

        if defaults.object(forKey: Keys.emergencyArmedAt) as? Date != nil {
            return .armedWaitingLongPress
        }

        let lastTap = defaults.object(forKey: Keys.emergencyLastTapAt) as? Date
        var count = defaults.integer(forKey: Keys.emergencyTapCount)
        if let lastTap, now.timeIntervalSince(lastTap) > emergencyTapSequenceWindow {
            count = 0
        }

        count += 1
        defaults.set(count, forKey: Keys.emergencyTapCount)
        defaults.set(now, forKey: Keys.emergencyLastTapAt)

        if count >= emergencyRequiredTapCount {
            defaults.set(now, forKey: Keys.emergencyArmedAt)
            defaults.set(0, forKey: Keys.emergencyTapCount)
        }
        flush(defaults)
        return emergencyInteractionPhase(now: now)
    }

    /// 5연타 후 길게 누를 때 — 성공 시 true.
    static func confirmEmergencyLongPress(now: Date = Date()) -> Bool {
        guard let defaults else { return false }
        if let last = lastEmergencySentAt,
           now.timeIntervalSince(last) < emergencySendCooldownSeconds {
            return false
        }
        guard let armedAt = defaults.object(forKey: Keys.emergencyArmedAt) as? Date else {
            return false
        }
        let elapsed = now.timeIntervalSince(armedAt)
        guard elapsed >= emergencyLongPressHoldAfterArm,
              elapsed <= emergencyArmTimeout else {
            resetEmergencyInteraction()
            return false
        }

        resetEmergencyInteraction()
        return true
    }

    static var lastEmergencySentAt: Date? {
        get { defaults?.object(forKey: Keys.lastEmergencySentAt) as? Date }
        set {
            guard let defaults else { return }
            if let newValue {
                defaults.set(newValue, forKey: Keys.lastEmergencySentAt)
            } else {
                defaults.removeObject(forKey: Keys.lastEmergencySentAt)
            }
            flush(defaults)
        }
    }

    static func isEmergencyOnCooldown(now: Date = Date()) -> Bool {
        guard let last = lastEmergencySentAt else { return false }
        return now.timeIntervalSince(last) < emergencySendCooldownSeconds
    }

    private static func pruneExpiredEmergencyArm(now: Date, defaults: UserDefaults) {
        guard let armedAt = defaults.object(forKey: Keys.emergencyArmedAt) as? Date else { return }
        if now.timeIntervalSince(armedAt) > emergencyArmTimeout {
            defaults.removeObject(forKey: Keys.emergencyArmedAt)
            defaults.removeObject(forKey: Keys.emergencyTapCount)
            defaults.removeObject(forKey: Keys.emergencyLastTapAt)
            flush(defaults)
        }
    }

    /// 마지막 탭 후 2초가 지나면 저장된 연타 횟수를 0으로 (위젯 표시 동기화).
    private static func pruneExpiredEmergencyTapSequence(now: Date, defaults: UserDefaults) {
        guard defaults.object(forKey: Keys.emergencyArmedAt) == nil else { return }
        guard let lastTap = defaults.object(forKey: Keys.emergencyLastTapAt) as? Date else { return }
        let count = defaults.integer(forKey: Keys.emergencyTapCount)
        guard count > 0 else { return }
        guard now.timeIntervalSince(lastTap) > emergencyTapSequenceWindow else { return }
        defaults.set(0, forKey: Keys.emergencyTapCount)
        defaults.removeObject(forKey: Keys.emergencyLastTapAt)
        flush(defaults)
    }

    static let nudgeCooldownSeconds: TimeInterval = 10

    /// App Group `UserDefaults` — 컨테이너 없으면 nil (크래시 없이 no-op).
    static var isAppGroupAvailable: Bool {
        AppGroupConfig.isContainerAvailable && cachedGroupDefaults != nil
    }

    private static let cachedGroupDefaults: UserDefaults? = {
        guard AppGroupConfig.isContainerAvailable else {
            #if DEBUG
            print(
                "⚠️ [AppGroup] 컨테이너 없음 — suite=\(AppGroupConfig.suiteName). " +
                    "entitlements·Developer Portal App Group 설정을 확인하세요."
            )
            #endif
            return nil
        }
        return UserDefaults(suiteName: AppGroupConfig.suiteName)
    }()

    private static var defaults: UserDefaults? {
        cachedGroupDefaults
    }

    static var currentRoomId: String? {
        get {
            defaults?.string(forKey: Keys.currentRoomId) ?? defaults?.string(forKey: Keys.roomId)
        }
        set {
            guard let defaults else { return }
            if let newValue {
                defaults.set(newValue, forKey: Keys.currentRoomId)
                defaults.set(newValue, forKey: Keys.roomId)
            } else {
                defaults.removeObject(forKey: Keys.currentRoomId)
                defaults.removeObject(forKey: Keys.roomId)
            }
            flush(defaults)
        }
    }

    static var currentUserId: String? {
        get {
            defaults?.string(forKey: Keys.currentUserId) ?? defaults?.string(forKey: Keys.userId)
        }
        set {
            guard let defaults else { return }
            if let newValue {
                defaults.set(newValue, forKey: Keys.currentUserId)
                defaults.set(newValue, forKey: Keys.userId)
            } else {
                defaults.removeObject(forKey: Keys.currentUserId)
                defaults.removeObject(forKey: Keys.userId)
            }
            flush(defaults)
        }
    }

    static var widgetHeartTapCount: Int {
        get { defaults?.integer(forKey: Keys.widgetHeartTapCount) ?? 0 }
        set {
            guard let defaults else { return }
            defaults.set(newValue, forKey: Keys.widgetHeartTapCount)
            flush(defaults)
        }
    }

    static func recordWidgetHeartSent() {
        widgetHeartTapCount = widgetHeartTapCount + 1
        guard let defaults else { return }
        defaults.set(Date(), forKey: Keys.lastWidgetHeartSentAt)
        flush(defaults)
    }

    static func isWidgetHeartThrottled(minInterval: TimeInterval) -> Bool {
        guard let last = defaults?.object(forKey: Keys.lastWidgetHeartSentAt) as? Date else {
            return false
        }
        return Date().timeIntervalSince(last) < minInterval
    }

    static var lastNudgeSentAt: Date? {
        get { defaults?.object(forKey: Keys.lastNudgeSentAt) as? Date }
        set {
            guard let defaults else { return }
            defaults.set(newValue, forKey: Keys.lastNudgeSentAt)
            flush(defaults)
        }
    }

    static var resolvedRoomUUID: UUID? {
        guard let raw = currentRoomId else { return nil }
        return UUID(uuidString: raw)
    }

    /// 잠금화면 위젯 키캡 전송 대상 방 (미설정 시 `currentRoomId`).
    static var widgetTargetRoomId: String? {
        get { defaults?.string(forKey: Keys.widgetTargetRoomId) }
        set {
            guard let defaults else { return }
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: Keys.widgetTargetRoomId)
            } else {
                defaults.removeObject(forKey: Keys.widgetTargetRoomId)
            }
            flush(defaults)
        }
    }

    static var resolvedWidgetRoomUUID: UUID? {
        if let target = widgetTargetRoomId, let id = UUID(uuidString: target) {
            return id
        }
        return resolvedRoomUUID
    }

    static var currentSenderNickname: String? {
        get { defaults?.string(forKey: Keys.currentSenderNickname) }
        set {
            guard let defaults else { return }
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: Keys.currentSenderNickname)
            } else {
                defaults.removeObject(forKey: Keys.currentSenderNickname)
            }
            flush(defaults)
        }
    }

    static var isWidgetSendConfigured: Bool {
        guard let userId = currentUserId, !userId.isEmpty,
              resolvedWidgetRoomUUID != nil else {
            return false
        }
        return true
    }

    static var isSessionConfigured: Bool {
        guard let roomId = currentRoomId, !roomId.isEmpty,
              let userId = currentUserId, !userId.isEmpty else {
            return false
        }
        return UUID(uuidString: roomId) != nil
    }

    static var isOnCooldown: Bool {
        guard let lastNudgeSentAt else { return false }
        return Date().timeIntervalSince(lastNudgeSentAt) < nudgeCooldownSeconds
    }

    static var cooldownRemainingSeconds: Int {
        guard let lastNudgeSentAt else { return 0 }
        let remaining = nudgeCooldownSeconds - Date().timeIntervalSince(lastNudgeSentAt)
        return max(0, Int(ceil(remaining)))
    }

    /// 위젯 푸시 — 메인 앱에서 갱신한 방 표시 이름.
    static func setPushRoomDisplayTitle(_ title: String, for roomId: UUID) {
        guard let defaults else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var map = pushRoomDisplayTitleMap()
        map[roomId.uuidString] = trimmed
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: Keys.pushRoomDisplayTitles)
            flush(defaults)
        }
    }

    static func pushRoomDisplayTitle(for roomId: UUID) -> String? {
        let raw = pushRoomDisplayTitleMap()[roomId.uuidString]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (raw?.isEmpty == false) ? raw : nil
    }

    private static func pushRoomDisplayTitleMap() -> [String: String] {
        guard let defaults,
              let data = defaults.data(forKey: Keys.pushRoomDisplayTitles),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func syncSession(roomId: UUID, userId: String, senderNickname: String? = nil) {
        guard let defaults else { return }
        let roomString = roomId.uuidString
        defaults.set(roomString, forKey: Keys.currentRoomId)
        defaults.set(roomString, forKey: Keys.roomId)
        defaults.set(userId, forKey: Keys.currentUserId)
        defaults.set(userId, forKey: Keys.userId)
        if let nick = senderNickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nick.isEmpty {
            defaults.set(nick, forKey: Keys.currentSenderNickname)
        }
        flush(defaults)
    }

    static func syncUserId(_ userId: String) {
        guard let defaults else { return }
        defaults.set(userId, forKey: Keys.currentUserId)
        defaults.set(userId, forKey: Keys.userId)
        flush(defaults)
    }

    /// 방 연결만 해제 (userId는 유지 — 다음 방에서 sender_id로 사용).
    static func clearRoomSession() {
        guard let defaults else { return }
        defaults.removeObject(forKey: Keys.currentRoomId)
        defaults.removeObject(forKey: Keys.roomId)
        flush(defaults)
    }

    static func debugSummary() -> String {
        let groupStatus = isAppGroupAvailable ? "AppGroup OK" : "AppGroup unavailable"
        let room = currentRoomId ?? "없음"
        let user = currentUserId.map { String($0.prefix(8)) + "…" } ?? "없음"
        let linked = isSessionConfigured ? "연동됨" : "미연동"
        return "\(groupStatus) · room: \(room) · user: \(user) · \(linked)"
    }

    /// `synchronize()`는 확장 프로세스에서 cfprefsd 경고·불안정을 유발할 수 있어 사용하지 않습니다.
    private static func flush(_ defaults: UserDefaults) {
        _ = defaults
    }
}
