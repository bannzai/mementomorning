import XCTest
@testable import MementoMorning

/// ホーム画面ウィジェットのタイムライン更新日時のテスト
final class HomeWidgetTimelineTests: XCTestCase {
    /// テストの結果をタイムゾーン設定に依存させないため、UTC 固定のカレンダーを使う
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testReloadDateIsStartOfNextDay() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 6, minute: 30))!

        XCTAssertEqual(
            homeWidgetReloadDate(now: now, calendar: calendar),
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 18))!
        )
    }

    func testReloadDateJustBeforeMidnightIsNextDay() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 23, minute: 59, second: 59))!

        XCTAssertEqual(
            homeWidgetReloadDate(now: now, calendar: calendar),
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 18))!
        )
    }

    func testReloadDateAtExactMidnightIsFollowingMidnight() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))!

        XCTAssertEqual(
            homeWidgetReloadDate(now: now, calendar: calendar),
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 18))!
        )
    }

    func testReloadDateAcrossMonthEnd() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 12))!

        XCTAssertEqual(
            homeWidgetReloadDate(now: now, calendar: calendar),
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        )
    }
}
