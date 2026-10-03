//
//  BipbiPagerEasterEgg.swift
//  SignalApp + SignalWidgetExtension
//

import Foundation

/// 잠금화면·앱 키캡 순서 기반 삐삐(페이저) 숫자 조합 이스터에그 — UI 없음.
/// `recordTap`은 전송·`isSending`과 무관하게 **모든 탭**에서 호출. 📞 시 사전 일치하면 추가 넛지 content 반환.
enum BipbiPagerEasterEgg {
    static let storagePrefix = "bipbi|"
    private static let sequenceTypesKey = "bipbiTapSequenceTypes"

    private static let typeToDial: [String: Character] = [
        "heart": "1", "pleading": "2", "tongue": "3", "question": "4",
        "play": "5", "angry": "6", "sleep": "7", "grin": "8",
        "clover": "9", "pencil": "*", "hungry": "0", "tired": "#",
    ]

    private static let sendTriggerType = "doc"

    private static let codeToMessage: [(code: String, message: String)] = [
        ("012486", "(๑♥‿♥๑)∞ 영원히 사랑해"),
        ("10288", "(🤒 >﹏<;)🔥 열이 펄펄"),
        ("7942", "( •◡•)🤝(•◡• ) 친구 사이"),
        ("9090", "(ง˙∇˙)ว 🏃💨 가자 가자 go go"),
        ("1472", "( •̀ᴗ•́ )و ̑̑ 일사천리=잘 되고 있어"),
        ("7179", "(๑>◡<๑)人(๑>◡<๑) 친한 친구"),
        ("9413", "(ㅠ_ㅠ;) 겨우 살았다"),
        ("1414", "(๑'؂'๑)🍚 밥 먹자"),
        ("0124", "(｡♥‿♥｡)∞ 영원히 사랑해"),
        ("0404", "(♥_♥)∞ 영원히 사랑해"),
        ("0024", "(ღ˘ω˘ღ)∞ 영원히 사랑해"),
        ("1052", "(ღ˘⌣˘ღ)♥ 사랑해=LOVE"),
        ("1004", "(｡♥‿♥｡)🪽 천사"),
        ("0242", "(｡♥ 3 ♥｡)💑 연인 사이"),
        ("401", "(｡♥‿♥｡)∞ 사랑은 영원할 거야"),
        ("504", "(๑ơ ₃ ơ)♥ 오직 너만을 사랑해"),
        ("952", "(๑❛ᴗ❛๑)☕ 좋은 아침, 굿모닝"),
        ("981", "(ಥ_ಥ)👋 잘가, 굿바이"),
        ("486", "(๑>◡<๑)♥ 사랑해"),
        ("100", "(•̯́ ₃ •̯̀｡) 🏃💨 돌아와"),
    ].sorted { $0.code.count > $1.code.count }

    static func isBipbiNudgeContent(_ content: String?) -> Bool {
        content?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(storagePrefix) == true
    }

    static func displayText(fromStoredContent content: String?) -> String? {
        guard let raw = content?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.hasPrefix(storagePrefix) {
            let text = String(raw.dropFirst(storagePrefix.count))
            return text.isEmpty ? nil : text
        }
        return nil
    }

    /// 키캡 **탭 직후** 호출 (전송 성공 여부와 무관). 📞 + 사전 일치 시 `bipbi|…` content, 아니면 `nil`.
    static func recordTap(symbolKey rawKey: String) -> String? {
        let key = AppGroupStorage.normalizedKeycapType(rawKey)

        if key == sendTriggerType {
            return consumeBonusIfMatching()
        }

        if typeToDial[key] != nil {
            appendToSequence(type: key)
            return nil
        }

        clearSequence()
        return nil
    }

    private static func consumeBonusIfMatching() -> String? {
        defer { clearSequence() }

        let types = currentSequence()
        guard !types.isEmpty,
              let converted = message(forDialSequence: dialString(from: types)) else {
            return nil
        }
        return storagePrefix + converted
    }

    private static func dialString(from types: [String]) -> String {
        types.compactMap { typeToDial[$0].map(String.init) }.joined()
    }

    private static func message(forDialSequence sequence: String) -> String? {
        let trimmed = sequence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for entry in codeToMessage where entry.code == trimmed {
            return entry.message
        }
        return nil
    }

    private static func appendToSequence(type: String) {
        var types = currentSequence()
        guard types.count < 12 else {
            clearSequence()
            return
        }
        types.append(type)
        writeSequence(types)
    }

    private static func currentSequence() -> [String] {
        guard let defaults,
              let data = defaults.data(forKey: sequenceTypesKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func writeSequence(_ types: [String]) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(types) {
            defaults.set(data, forKey: sequenceTypesKey)
        }
        defaults.synchronize()
    }

    private static func clearSequence() {
        guard let defaults else { return }
        defaults.removeObject(forKey: sequenceTypesKey)
        defaults.synchronize()
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupStorage.suiteName)
    }
}
