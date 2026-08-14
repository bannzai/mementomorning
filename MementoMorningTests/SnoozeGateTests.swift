import XCTest
@testable import MementoMorning

/// shouldChase (追撃アラーム再登録の可否判定) のテスト。
/// 無料は freeTierSnoozeLimit (2 回) を境界に打ち切られ、プレミアムは回数によらず追撃されることを確認する
final class SnoozeGateTests: XCTestCase {
    func testFreeTierChasesUntilLimit() {
        XCTAssertTrue(shouldChase(chaseCount: 0, isPremium: false))
        XCTAssertTrue(shouldChase(chaseCount: 1, isPremium: false))
    }

    func testFreeTierStopsChasingAtLimit() {
        XCTAssertFalse(shouldChase(chaseCount: freeTierSnoozeLimit, isPremium: false))
        XCTAssertFalse(shouldChase(chaseCount: freeTierSnoozeLimit + 1, isPremium: false))
    }

    func testPremiumChasesWithoutLimit() {
        XCTAssertTrue(shouldChase(chaseCount: 0, isPremium: true))
        XCTAssertTrue(shouldChase(chaseCount: freeTierSnoozeLimit, isPremium: true))
        XCTAssertTrue(shouldChase(chaseCount: 100, isPremium: true))
    }

    func testFreeTierSnoozeLimitMatchesPricingPlan() {
        // documents/PROJECT.md の課金設計「スヌーズ 2 回まで」と一致していることを固定する
        XCTAssertEqual(freeTierSnoozeLimit, 2)
    }
}
