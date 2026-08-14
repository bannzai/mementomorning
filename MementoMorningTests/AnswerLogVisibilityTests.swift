import XCTest
@testable import MementoMorning

/// AnswerLogVisibility の無料枠 (直近 7 日) 判定のテスト
final class AnswerLogVisibilityTests: XCTestCase {
    /// 時刻依存を避けるため固定日 (2026-08-13 07:00) を基準にする
    private let calendar = Calendar(identifier: .gregorian)
    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 13, hour: 7))!
    }

    /// 日単位で daysAgo 日前の日付を作る
    private func date(daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: today)!
    }

    func testTodayAnswerIsVisibleInFreeTier() {
        XCTAssertTrue(AnswerLogVisibility.isVisible(answeredDate: date(daysAgo: 0), isPremium: false, today: today, calendar: calendar))
    }

    func testSixDaysAgoAnswerIsVisibleInFreeTier() {
        XCTAssertTrue(AnswerLogVisibility.isVisible(answeredDate: date(daysAgo: 6), isPremium: false, today: today, calendar: calendar))
    }

    func testSevenDaysAgoAnswerIsHiddenInFreeTier() {
        XCTAssertFalse(AnswerLogVisibility.isVisible(answeredDate: date(daysAgo: 7), isPremium: false, today: today, calendar: calendar))
    }

    func testThirtyDaysAgoAnswerIsVisibleWithPremium() {
        XCTAssertTrue(AnswerLogVisibility.isVisible(answeredDate: date(daysAgo: 30), isPremium: true, today: today, calendar: calendar))
    }
}
