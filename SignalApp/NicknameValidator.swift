//
//  NicknameValidator.swift
//  SignalApp
//

import Foundation

enum NicknameValidator {
    static func isValid(_ nickname: String) -> Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...32).contains(trimmed.count) else { return false }
        return trimmed.allSatisfy { character in
            guard character.unicodeScalars.count == 1,
                  let scalar = character.unicodeScalars.first else { return false }
            return scalar.isASCII && (character.isLetter || character.isNumber)
        }
    }

    /// 방 만들기 버튼 활성화용 (형식은 createRoom에서 한 번 더 검증).
    static func canSubmit(_ nickname: String) -> Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func sanitizedInput(_ input: String) -> String {
        input.filter { character in
            guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
                return false
            }
            return scalar.isASCII && (character.isLetter || character.isNumber)
        }
    }
}

enum InviteCodeValidator {
    static func sanitizedInput(_ input: String) -> String {
        NicknameValidator.sanitizedInput(input)
    }

    static func isValidLength(_ code: String) -> Bool {
        code.count == 12
    }
}
