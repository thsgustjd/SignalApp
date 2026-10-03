//
//  UserFacingErrorMessage.swift
//  SignalApp
//

import Foundation

enum UserFacingErrorMessage {
    static let loadFailure = "데이터를 불러오는 중 문제가 발생했습니다. 다시 시도해 주세요."
    static let actionFailure = "요청을 처리하는 중 문제가 발생했습니다. 다시 시도해 주세요."

    /// 취소·무시 가능한 오류면 `nil`, 아니면 로딩 실패 안내 문구(또는 앱 도메인 오류 설명).
    static func loadMessage(from error: Error) -> String? {
        guard !shouldSilentlyIgnore(error) else { return nil }
        if let domain = appDomainMessage(from: error) { return domain }
        return loadFailure
    }

    /// 취소·무시 가능한 오류면 `nil`, 아니면 액션 실패 안내 문구(또는 앱 도메인 오류 설명).
    static func actionMessage(from error: Error) -> String? {
        guard !shouldSilentlyIgnore(error) else { return nil }
        if let domain = appDomainMessage(from: error) { return domain }
        return actionFailure
    }

    static func shouldSilentlyIgnore(_ error: Error) -> Bool {
        if Task.isCancelled { return true }

        var current: Error? = error
        while let err = current {
            if err is CancellationError { return true }
            if let urlError = err as? URLError, urlError.code == .cancelled { return true }

            let ns = err as NSError
            if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled { return true }

            current = ns.userInfo[NSUnderlyingErrorKey] as? Error
        }

        let described = String(describing: error)
        if described.contains("CancellationError") { return true }

        let localized = error.localizedDescription
        if localized == "cancelled" || localized == "Canceled" { return true }

        return false
    }

    private static func appDomainMessage(from error: Error) -> String? {
        if let supabase = error as? SupabaseManagerError {
            return supabase.errorDescription
        }
        if let safety = error as? UserSafetyError {
            return safety.errorDescription
        }
        if let heart = error as? HeartUsageError {
            return heart.errorDescription
        }
        return nil
    }
}
