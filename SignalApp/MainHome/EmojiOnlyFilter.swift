//
//  EmojiOnlyFilter.swift
//  SignalApp
//

import Foundation

enum EmojiOnlyFilter {
    /// 한글·영문·숫자·일반 기호를 제거하고 Unicode 이모티콘(이모지 시퀀스)만 남깁니다.
    static func sanitized(_ input: String) -> String {
        input.filter { $0.isEmojiOnlyCharacter }
    }

    static func canSend(_ input: String) -> Bool {
        !sanitized(input).isEmpty
    }
}

private extension Character {
    var isEmojiOnlyCharacter: Bool {
        unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation
                || (scalar.properties.isEmoji && !scalar.properties.isASCIIHexDigit)
        }
    }
}
