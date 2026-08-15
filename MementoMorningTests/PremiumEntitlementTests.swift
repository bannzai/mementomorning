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
