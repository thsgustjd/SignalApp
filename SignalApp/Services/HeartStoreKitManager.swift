//
//  HeartStoreKitManager.swift
//  SignalApp
//

import Foundation
import StoreKit

@MainActor
final class HeartStoreKitManager: ObservableObject {
    static let shared = HeartStoreKitManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPurchasing = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { await listenForTransactions() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        let ids = Set(HeartCatalog.packs.map(\.id))
        do {
            products = try await Product.products(for: ids).sorted { $0.price < $1.price }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await deliver(transaction: transaction, productId: product.id)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                lastError = "구매 승인 대기 중입니다."
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func deliver(transaction: Transaction, productId: String) async {
        guard let hearts = HeartCatalog.hearts(forProductId: productId) else { return }
        let txId = String(transaction.id)
        do {
            try await HeartWalletService.shared.grantIAP(
                productId: productId,
                transactionId: txId,
                hearts: hearts
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            do {
                let transaction = try checkVerified(update)
                if let hearts = HeartCatalog.hearts(forProductId: transaction.productID) {
                    try? await HeartWalletService.shared.grantIAP(
                        productId: transaction.productID,
                        transactionId: String(transaction.id),
                        hearts: hearts
                    )
                }
                await transaction.finish()
            } catch {
                continue
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw HeartUsageError.server("결제 검증에 실패했습니다.")
        case .verified(let safe):
            return safe
        }
    }
}
