import StoreKit
import StoreKitTest
import XCTest

/// StoreKit Configuration file (MementoMorning.storekit) の検証。
/// SKTestSession がテストバンドル内の .storekit を読み込むため、ASC・ネットワークに触れず
/// CLI (xcodebuild test) だけで「商品解決 → 購入 → entitlement 付与」まで確認できる。
/// simctl launch には StoreKit Configuration を渡す手段が無いため、CLI からの課金検証はこの経路を使う
final class StoreKitConfigurationTests: XCTestCase {
    /// iOS 26.5 の simulator では xcodebuild test 経由の StoreKit Testing が機能しない既知の問題があるため skip する。
    /// SKTestSession の init は成功するのに設定が適用されず、商品解決が実ストア (sandbox) に落ち、
    /// buyProduct は StoreKitError.notEntitled を投げる (iOS 26.5 で実測。iOS 26.2 では全項目 pass。
    /// Apple Developer Forums でも iOS 26.5 simulator の CI 利用で同様の報告あり)
    private func skipOnBrokenSimulatorRuntime() throws {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        try XCTSkipIf(
            version.majorVersion == 26 && version.minorVersion == 5,
            "iOS 26.5 simulator では StoreKit Testing が StoreKitError.notEntitled で機能しない (iOS 26.2 以下の runtime で実行する)"
        )
    }

    /// 3 商品が documents/PROJECT.md の確定価格どおりに解決されること
    func testProductsResolveWithConfirmedPrices() async throws {
        try skipOnBrokenSimulatorRuntime()
        let session = try SKTestSession(configurationFileNamed: "MementoMorning")
        session.resetToDefaultState()
        session.clearTransactions()

        let products = try await Product.products(for: [
            "mementomorning_premium_monthly",
            "mementomorning_premium_annual",
            "mementomorning_lifetime",
        ])
        let productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        XCTAssertEqual(productsByID.count, 3)
        XCTAssertEqual(productsByID["mementomorning_premium_monthly"]?.price, 800)
        XCTAssertEqual(productsByID["mementomorning_premium_annual"]?.price, 6000)
        XCTAssertEqual(productsByID["mementomorning_lifetime"]?.price, 9800)

        XCTAssertEqual(productsByID["mementomorning_premium_monthly"]?.subscription?.subscriptionPeriod.unit, .month)
        XCTAssertEqual(productsByID["mementomorning_premium_annual"]?.subscription?.subscriptionPeriod.unit, .year)
        XCTAssertNil(productsByID["mementomorning_lifetime"]?.subscription)

        // 7 日間の無料トライアルは年額のみ (ASC の設定と一致させている)
        XCTAssertEqual(productsByID["mementomorning_premium_annual"]?.subscription?.introductoryOffer?.paymentMode, .freeTrial)
        XCTAssertNil(productsByID["mementomorning_premium_monthly"]?.subscription?.introductoryOffer)
    }

    /// テスト購入でトランザクションが成立し、現在の entitlement に現れること
    func testBuyLifetimeGrantsEntitlement() async throws {
        try skipOnBrokenSimulatorRuntime()
        let session = try SKTestSession(configurationFileNamed: "MementoMorning")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true

        _ = try await session.buyProduct(identifier: "mementomorning_lifetime")

        var entitledProductIDs: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                entitledProductIDs.insert(transaction.productID)
            }
        }
        XCTAssertTrue(entitledProductIDs.contains("mementomorning_lifetime"))
    }
}
