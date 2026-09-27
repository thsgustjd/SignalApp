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
        "cold": "추워",
        "hot": "더워",
        "play": "놀자"
    ]

    static let keycapNudgeTypeOrder: [String] = [
        "heart", "pleading", "tongue", "question", "play", "angry", "sleep", "grin", "clover",
        "pencil", "doc", "tired", "hungry", "cold", "hot"
    ]

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
    ]

    static func normalizedKeycapType(_ raw: String) -> String {
        legacyKeycapTypeMap[raw] ?? raw
    }

    static func isActiveKeycapType(_ type: String) -> Bool {
        keycapNudgeTypeOrder.contains(type)
    }

    /// 이모지 각인 키캡이면 이모지 문자열, SF Symbol 키캡이면 nil.
    static func keycapEmoji(for nudgeType: String) -> String? {
        switch normalizedKeycapType(nudgeType) {
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
        case "cold": return "😬"
        case "hot": return "🥵"
        case "play": return "😆"
        case "question": return "👀"
        default: return nil
        }
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

    private static func loadCustomKeycapMessages() -> [String: String] {
        guard let defaults,
              let data = defaults.data(forKey: Keys.keycapCustomMessages),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    /// 넛지 `content`에서 키캡 심볼 키 추출 (`star|문구`, 레거시 `star`, 문구 매칭).
    static func keycapSymbolKey(fromNudgeContent content: String?) -> String? {
        guard let raw = content?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
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
            return (emoji, shortTitle(for: type, fallback: defaultKeycapMessages[type] ?? type))
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
        case "cold": return "추워"
        case "hot": return "더워"
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

        if defaults.object(forKey: Keys.emergencyArmedAt) as? Date != nil {
            return .armedWaitingLongPress
        }

        let count = defaults.integer(forKey: Keys.emergencyTapCount)
        return .counting(current: count, required: emergencyRequiredTapCount)
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
