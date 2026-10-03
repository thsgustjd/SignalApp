//
//  HeartWalletService.swift
//  SignalApp
//

import Foundation
import Supabase

struct HeartWalletSnapshot: Equatable {
    let heartBalance: Int
    let dailyFreeRemaining: Int
    let unlimitedUntil: Date?

    var isUnlimitedActive: Bool {
        guard let unlimitedUntil else { return false }
        return unlimitedUntil > Date()
    }
}

enum HeartUsageError: LocalizedError {
    case notSignedIn
    case dailyExhausted
    case insufficientHearts
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "로그인이 필요합니다."
        case .dailyExhausted:
            return "오늘 무료 이용(100회)을 모두 사용했어요. 하트 1개로 30일 무제한을 이용하거나 내일 다시 이용해 주세요."
        case .insufficientHearts:
            return "하트가 부족합니다."
        case .server(let message):
            return message
        }
    }
}

@MainActor
final class HeartWalletService: ObservableObject {
    static let shared = HeartWalletService()

    @Published private(set) var snapshot: HeartWalletSnapshot?

    private let manager = SupabaseManager.shared

    private init() {}

    func refresh() async {
        do {
            let row: HeartWalletRow = try await manager.client
                .rpc("ensure_heart_wallet")
                .execute()
                .value
            apply(row: row)
        } catch {
            print("❌ [Heart] refresh failed: \(error)")
        }
    }

    func consumeUsage(action: String = "generic") async throws {
        guard manager.client.auth.currentSession != nil else {
            throw HeartUsageError.notSignedIn
        }

        struct ConsumeParams: Encodable { let p_action: String }
        let payload: HeartConsumeResponse = try await manager.client
            .rpc("consume_heart_usage", params: ConsumeParams(p_action: action))
            .execute()
            .value

        guard payload.allowed else {
            if payload.reason == "daily_exhausted" {
                throw HeartUsageError.dailyExhausted
            }
            throw HeartUsageError.server(payload.reason ?? "이용할 수 없습니다.")
        }

        snapshot = HeartWalletSnapshot(
            heartBalance: payload.heartBalance ?? snapshot?.heartBalance ?? 0,
            dailyFreeRemaining: payload.dailyFreeRemaining ?? snapshot?.dailyFreeRemaining ?? 0,
            unlimitedUntil: payload.unlimitedUntil
        )
        syncToAppGroup()
    }

    func purchaseUnlimitedMonth() async throws {
        let payload: HeartUnlimitedResponse = try await manager.client
            .rpc("purchase_unlimited_month_with_one_heart")
            .execute()
            .value

        guard payload.ok else {
            if payload.reason == "insufficient_hearts" {
                throw HeartUsageError.insufficientHearts
            }
            throw HeartUsageError.server(payload.reason ?? "구매에 실패했습니다.")
        }

        snapshot = HeartWalletSnapshot(
            heartBalance: payload.heartBalance ?? 0,
            dailyFreeRemaining: payload.dailyFreeRemaining ?? snapshot?.dailyFreeRemaining ?? 0,
            unlimitedUntil: payload.unlimitedUntil
        )
        syncToAppGroup()
    }

    func grantIAP(productId: String, transactionId: String, hearts: Int) async throws {
        struct Params: Encodable {
            let p_product_id: String
            let p_transaction_id: String
            let p_hearts: Int64
        }
        let payload: HeartGrantResponse = try await manager.client
            .rpc(
                "grant_hearts_iap",
                params: Params(
                    p_product_id: productId,
                    p_transaction_id: transactionId,
                    p_hearts: Int64(hearts)
                )
            )
            .execute()
            .value

        guard payload.ok else {
            throw HeartUsageError.server(payload.reason ?? "충전에 실패했습니다.")
        }

        await refresh()
    }

    private func apply(row: HeartWalletRow) {
        snapshot = HeartWalletSnapshot(
            heartBalance: Int(row.heartBalance),
            dailyFreeRemaining: row.dailyFreeRemaining,
            unlimitedUntil: row.unlimitedUntil
        )
        syncToAppGroup()
    }

    private func syncToAppGroup() {
        guard let snapshot else { return }
        AppGroupStorage.syncHeartQuota(
            dailyFreeRemaining: snapshot.dailyFreeRemaining,
            unlimitedUntil: snapshot.unlimitedUntil
        )
    }
}

// MARK: - RPC JSON

private struct HeartWalletRow: Decodable {
    let heartBalance: Int64
    let dailyFreeRemaining: Int
    let unlimitedUntil: Date?

    enum CodingKeys: String, CodingKey {
        case heartBalance = "heart_balance"
        case dailyFreeRemaining = "daily_free_remaining"
        case unlimitedUntil = "unlimited_until"
    }
}

private struct HeartConsumeResponse: Decodable {
    let allowed: Bool
    let reason: String?
    let heartBalance: Int?
    let dailyFreeRemaining: Int?
    let unlimitedUntil: Date?

    enum CodingKeys: String, CodingKey {
        case allowed, reason
        case heartBalance = "heart_balance"
        case dailyFreeRemaining = "daily_free_remaining"
        case unlimitedUntil = "unlimited_until"
    }
}

private struct HeartUnlimitedResponse: Decodable {
    let ok: Bool
    let reason: String?
    let heartBalance: Int?
    let dailyFreeRemaining: Int?
    let unlimitedUntil: Date?

    enum CodingKeys: String, CodingKey {
        case ok, reason
        case heartBalance = "heart_balance"
        case dailyFreeRemaining = "daily_free_remaining"
        case unlimitedUntil = "unlimited_until"
    }
}

private struct HeartGrantResponse: Decodable {
    let ok: Bool
    let reason: String?
}
