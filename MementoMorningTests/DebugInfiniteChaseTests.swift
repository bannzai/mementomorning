import XCTest

@testable import MementoMorning

/// 無限アラーム検証 (issue #97) の前提判定 (debugInfiniteChaseBlockers) のテスト。
/// 「有効なアラーム設定 + 実効スヌーズ上限が無制限 + 今日が未回答」が揃った時だけ空 (検証可能) になることを確認する
final class DebugInfiniteChaseTests: XCTestCase {
    func testNoBlockersWhenAllPreconditionsAreMet() {
        XCTAssertEqual(
            debugInfiniteChaseBlockers(alarmSettingIsEnabled: true, snoozeLimit: nil, isPremium: true, hasTodayAnswer: false),
            []
        )
    }

    func testMissingAlarmSettingIsBlocked() {
        let blockers = debugInfiniteChaseBlockers(alarmSettingIsEnabled: nil, snoozeLimit: nil, isPremium: true, hasTodayAnswer: false)
        XCTAssertEqual(blockers.count, 1)
        XCTAssertTrue(blockers[0].contains("アラーム設定"))
    }

    func testDisabledAlarmSettingIsBlocked() {
        let blockers = debugInfiniteChaseBlockers(alarmSettingIsEnabled: false, snoozeLimit: nil, isPremium: true, hasTodayAnswer: false)
        XCTAssertEqual(blockers.count, 1)
        XCTAssertTrue(blockers[0].contains("アラーム設定"))
    }

    func testFiniteSnoozeLimitOnPremiumIsBlocked() {
        // プレミアムでも有限回数を選んでいれば無限追撃にならない
        let blockers = debugInfiniteChaseBlockers(alarmSettingIsEnabled: true, snoozeLimit: 5, isPremium: true, hasTodayAnswer: false)
        XCTAssertEqual(blockers.count, 1)
        XCTAssertTrue(blockers[0].contains("スヌーズ"))
    }

    func testFreeTierIsBlockedEvenWithUnlimitedSetting() {
        // 無料は設定が無制限でも effectiveSnoozeLimit が freeTierSnoozeLimit に丸めるため無限にならない
        let blockers = debugInfiniteChaseBlockers(alarmSettingIsEnabled: true, snoozeLimit: nil, isPremium: false, hasTodayAnswer: false)
        XCTAssertEqual(blockers.count, 1)
        XCTAssertTrue(blockers[0].contains("スヌーズ"))
    }

    func testTodayAnswerIsBlocked() {
        let blockers = debugInfiniteChaseBlockers(alarmSettingIsEnabled: true, snoozeLimit: nil, isPremium: true, hasTodayAnswer: true)
        XCTAssertEqual(blockers.count, 1)
        XCTAssertTrue(blockers[0].contains("回答"))
    }

    func testAllBlockersAreListedTogether() {
        XCTAssertEqual(
            debugInfiniteChaseBlockers(alarmSettingIsEnabled: nil, snoozeLimit: 2, isPremium: false, hasTodayAnswer: true).count,
            3
        )
    }
}
