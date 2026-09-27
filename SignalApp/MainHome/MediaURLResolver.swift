//
//  MediaURLResolver.swift
//  SignalApp
//

import Foundation

enum MediaURLResolver {
    /// DB/Storage에서 온 `media_url` 문자열 정리 (공백·줄바꿈 제거).
    static func sanitizedRaw(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// HTTP(S) 전체 URL 또는 Storage 상대 경로를 `URL`로 변환합니다.
    static func resolveHTTPURL(from raw: String) -> URL? {
        guard let cleaned = sanitizedRaw(raw) else { return nil }

        if cleaned.hasPrefix("http://") || cleaned.hasPrefix("https://") {
            return urlFromHTTPString(cleaned)
        }
        return nil
    }

    static func urlFromHTTPString(_ string: String) -> URL? {
        let cleaned = sanitizedRaw(string) ?? string

        if let direct = URL(string: cleaned), direct.host != nil {
            return direct
        }

        if let components = URLComponents(string: cleaned), let url = components.url, url.host != nil {
            return url
        }

        if let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded),
           url.host != nil {
            return url
        }

        var allowed = CharacterSet.urlFragmentAllowed
        allowed.formUnion(.urlPathAllowed)
        allowed.formUnion(.urlHostAllowed)
        if let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: allowed),
           let url = URL(string: encoded),
           url.host != nil {
            return url
        }

        print("⚠️ [MediaURL] URL 변환 실패 raw=\(cleaned.prefix(120))")
        return nil
    }
}
