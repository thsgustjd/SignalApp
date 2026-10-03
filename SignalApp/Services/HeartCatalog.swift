//
//  HeartCatalog.swift
//  SignalApp
//

import Foundation

enum HeartCatalog {
    static let dailyFreeAllowance = HeartEconomyConstants.dailyFreeAllowance
    static let unlimitedPassHeartCost = 1
    static let unlimitedPassDays = 30

    struct Pack: Identifiable {
        let id: String
        let hearts: Int
        let priceLabelKRW: String
    }

    /// App Store Connect Product ID 와 1:1 매칭 필요
    static let packs: [Pack] = [
        Pack(id: "com.hyunseong.SignalApp.heart.1000", hearts: 1_000, priceLabelKRW: "₩1,100"),
        Pack(id: "com.hyunseong.SignalApp.heart.5000", hearts: 5_000, priceLabelKRW: "₩5,000"),
        Pack(id: "com.hyunseong.SignalApp.heart.10000", hearts: 10_000, priceLabelKRW: "₩10,000"),
        Pack(id: "com.hyunseong.SignalApp.heart.50000", hearts: 50_000, priceLabelKRW: "₩50,000"),
        Pack(id: "com.hyunseong.SignalApp.heart.100000", hearts: 100_000, priceLabelKRW: "₩100,000"),
    ]

    static func hearts(forProductId id: String) -> Int? {
        packs.first { $0.id == id }?.hearts
    }

    static let oauthRedirectURL = URL(string: "com.hyunseong.signalapp://auth-callback")!
}
