//
//  HeartShopView.swift
//  SignalApp
//

import StoreKit
import SwiftUI

struct HeartShopView: View {
    @ObservedObject private var wallet = HeartWalletService.shared
    @ObservedObject private var store = HeartStoreKitManager.shared

    @State private var unlimitedBusy = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusCard

                    unlimitedSection

                    Text("하트 충전")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(CozyTheme.textPrimary)

                    if store.products.isEmpty {
                        ProgressView("상품 불러오는 중…")
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(store.products, id: \.id) { product in
                            packRow(product)
                        }
                    }

                    if let err = store.lastError {
                        Text(err).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(CozyTheme.roomBackground.ignoresSafeArea())
            .navigationTitle("하트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(CozyTheme.textPrimary)
                }
            }
            .task {
                await wallet.refresh()
                await store.loadProducts()
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("보유 하트 \(wallet.snapshot?.heartBalance ?? 0)개", systemImage: "heart.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(CozyTheme.deepBlue)
            if wallet.snapshot?.isUnlimitedActive == true, let until = wallet.snapshot?.unlimitedUntil {
                Text("무제한 이용 중 · \(until.formatted(date: .abbreviated, time: .omitted))까지")
                    .font(.subheadline)
                    .foregroundStyle(CozyTheme.textPrimary)
            } else {
                Text("오늘 무료 \(wallet.snapshot?.dailyFreeRemaining ?? HeartCatalog.dailyFreeAllowance)/\(HeartCatalog.dailyFreeAllowance)회")
                    .font(.subheadline)
                    .foregroundStyle(CozyTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CozyTheme.card, in: RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous)
                .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
        )
    }

    private var unlimitedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("30일 무제한 이용권")
                .font(.headline.weight(.bold))
                .foregroundStyle(CozyTheme.textPrimary)
            Text("하트 1개를 사용해 30일 동안 무료 횟수·하트 차감 없이 이용합니다.")
                .font(.caption)
                .foregroundStyle(CozyTheme.textPrimary)
            Button {
                Task { await buyUnlimited() }
            } label: {
                Group {
                    if unlimitedBusy {
                        ProgressView()
                    } else {
                        Text("하트 1개로 구매")
                            .font(.headline.weight(.bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(CozyTheme.deepBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .disabled(unlimitedBusy || store.isPurchasing)
        }
        .padding(16)
        .background(CozyTheme.card, in: RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous)
                .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
        )
    }

    private func packRow(_ product: Product) -> some View {
        let hearts = HeartCatalog.hearts(forProductId: product.id) ?? 0
        return Button {
            Task { await store.purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("하트 \(hearts.formatted())개")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(CozyTheme.textPrimary)
                    Text(product.displayPrice)
                        .font(.subheadline)
                        .foregroundStyle(CozyTheme.textPrimary)
                }
                Spacer()
                Image(systemName: "cart.fill")
                    .foregroundStyle(CozyTheme.deepBlue)
            }
            .padding(16)
            .background(CozyTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
            )
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing)
    }

    private func buyUnlimited() async {
        unlimitedBusy = true
        defer { unlimitedBusy = false }
        do {
            try await wallet.purchaseUnlimitedMonth()
        } catch {
            store.lastError = error.localizedDescription
        }
    }
}
