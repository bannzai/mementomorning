import RevenueCat
import XCTest
@testable import MementoMorning

/// キャッシュした課金判定の有効期限つき評価 (cachedPremiumActive) のテスト。
/// アプリ停止中の失効を無期限の true にしない (期限は now と同期比較する) ことを固定する
final class PremiumEntitlementTests: XCTestCase {
    /// 基準時刻。純粋関数のテストのため任意の固定値でよい
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testInactiveIsNotPremium() {
        XCTAssertFalse(cachedPremiumActive(active: false, expirationDate: nil, now: now))
        XCTAssertFalse(cachedPremiumActive(active: false, expirationDate: now.addingTimeInterval(3600), now: now))
    }

    func testActiveWithoutExpirationIsPremium() {
        // 買い切り (一生プラン) は expirationDate が無い = 失効しない
        XCTAssertTrue(cachedPremiumActive(active: true, expirationDate: nil, now: now))
    }

    func testActiveBeforeExpirationIsPremium() {
        XCTAssertTrue(cachedPremiumActive(active: true, expirationDate: now.addingTimeInterval(1), now: now))
    }

    func testActiveAfterExpirationIsNotPremium() {
        // アプリ停止中に失効した購読は、ストリームの再同期を待たず参照時点で false になる
        XCTAssertFalse(cachedPremiumActive(active: true, expirationDate: now, now: now))
        XCTAssertFalse(cachedPremiumActive(active: true, expirationDate: now.addingTimeInterval(-1), now: now))
    }
}

/// CustomerInfo から entitlement 判定をキャッシュする cacheEntitlement のテスト。
/// 応答の署名検証 (Trusted Entitlements) に通った entitlement だけをプレミアムとして保存することを固定する (issue #197)
final class PremiumEntitlementCacheTests: XCTestCase {
    /// テストが書き換える UserDefaults キー。テスト後に元の値へ戻す
    private let keys: [String] = [.premiumEntitlementActive, .premiumEntitlementExpiration]
    /// setUp 時点の各キーの値 (nil = 未保存)
    private var savedValues: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        savedValues = Dictionary(uniqueKeysWithValues: keys.map { ($0, UserDefaults.standard.object(forKey: $0)) })
        // 前回の実行やアプリ起動で残った値に結果が左右されないよう、未保存の状態から始める
        keys.forEach(UserDefaults.standard.removeObject(forKey:))
    }

    override func tearDown() {
        for (key, value) in savedValues {
            if let value {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    func testActiveAndVerifiedIsPremium() {
        cacheEntitlement(isActive: true, verification: .verified)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: .premiumEntitlementActive))
    }

    func testActiveAndVerifiedOnDeviceIsPremium() {
        cacheEntitlement(isActive: true, verification: .verifiedOnDevice)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: .premiumEntitlementActive))
    }

    func testActiveAndVerificationFailedIsNotPremium() {
        // キー未保存でも bool(forKey:) は false を返すため、true を入れてから false で上書きされることを確かめる
        UserDefaults.standard.set(true, forKey: .premiumEntitlementActive)
        cacheEntitlement(isActive: true, verification: .failed)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: .premiumEntitlementActive))
    }

    func testActiveAndVerificationNotRequestedIsNotPremium() {
        UserDefaults.standard.set(true, forKey: .premiumEntitlementActive)
        cacheEntitlement(isActive: true, verification: .notRequested)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: .premiumEntitlementActive))
    }

    func testInactiveAndVerifiedIsNotPremium() {
        UserDefaults.standard.set(true, forKey: .premiumEntitlementActive)
        cacheEntitlement(isActive: false, verification: .verified)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: .premiumEntitlementActive))
    }

    /// premium entitlement を 1 つ持つ CustomerInfo を作って PremiumEntitlement.cacheEntitlement に渡す。
    /// SDK は EntitlementInfo と EntitlementInfos に同じ verification を入れるため、テストでも両方に同じ値を渡す
    private func cacheEntitlement(isActive: Bool, verification: VerificationResult) {
        let entitlement = EntitlementInfo(
            identifier: PremiumEntitlement.entitlementIdentifier,
            isActive: isActive,
            willRenew: false,
            periodType: .normal,
            store: .appStore,
            productIdentifier: "lifetime",
            isSandbox: true,
            ownershipType: .purchased,
            verification: verification
        )
        PremiumEntitlement.cacheEntitlement(customerInfo: CustomerInfo(
            entitlements: EntitlementInfos(
                entitlements: [PremiumEntitlement.entitlementIdentifier: entitlement],
                verification: verification
            ),
            requestDate: .now,
            firstSeen: .now,
            originalAppUserId: "test"
        ))
    }
}
