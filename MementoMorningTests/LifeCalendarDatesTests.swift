import XCTest
@testable import MementoMorning

/// lifeCalendarDays のテスト
final class LifeCalendarDatesTests: XCTestCase {
    /// 実行環境のタイムゾーン・ロケールに結果が依存しないよう固定した Calendar (日曜始まり)
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }()

    /// 固定 Calendar 上の年月日から Date を作る
    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// 指定した日が属する週の開始日を返す
    private func weekStart(date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)!.start
    }

    func testNoAnswersShowsMinimum13Weeks() {
        let today = date(year: 2026, month: 8, day: 13)

        let days = lifeCalendarDays(answeredDates: [], today: today, calendar: calendar)

        XCTAssertEqual(days.count, 13 * 7)
        XCTAssertEqual(days.first, calendar.date(byAdding: .weekOfYear, value: -12, to: weekStart(date: today)))
        XCTAssertEqual(days.last, calendar.date(byAdding: .day, value: 6, to: weekStart(date: today)))
        XCTAssertTrue(days.contains(calendar.startOfDay(for: today)))
    }

    func testRecentAnswerKeepsMinimum13Weeks() {
        let today = date(year: 2026, month: 8, day: 13)

        let days = lifeCalendarDays(
            answeredDates: [date(year: 2026, month: 8, day: 1)],
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(days.count, 13 * 7)
    }

    func testOldAnswerExtendsRangeToItsWeek() {
        let today = date(year: 2026, month: 8, day: 13)
        // 今日の週の 20 週前に属する回答
        let oldAnsweredDate = calendar.date(byAdding: .weekOfYear, value: -20, to: today)!

        let days = lifeCalendarDays(answeredDates: [oldAnsweredDate], today: today, calendar: calendar)

        XCTAssertEqual(days.count, 21 * 7)
        XCTAssertEqual(days.first, weekStart(date: oldAnsweredDate))
    }

    func testEarliestOfMultipleAnswersDeterminesStart() {
        let today = date(year: 2026, month: 8, day: 13)
        let earliestAnsweredDate = calendar.date(byAdding: .weekOfYear, value: -30, to: today)!

        let days = lifeCalendarDays(
            answeredDates: [date(year: 2026, month: 8, day: 10), earliestAnsweredDate, calendar.date(byAdding: .weekOfYear, value: -15, to: today)!],
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(days.count, 31 * 7)
        XCTAssertEqual(days.first, weekStart(date: earliestAnsweredDate))
    }

    func testWeeksChunksDaysBySeven() {
        let today = date(year: 2026, month: 8, day: 13)
        let days = lifeCalendarDays(answeredDates: [], today: today, calendar: calendar)

        let weeks = lifeCalendarWeeks(days: days)

        XCTAssertEqual(weeks.count, 13)
        XCTAssertTrue(weeks.allSatisfy { $0.count == 7 })
        XCTAssertEqual(weeks.flatMap { $0 }, days)
    }

    func testMonthAnchorDayReturnsFirstOfMonth() {
        // 2026-08-01 (土) を含む週 (日曜始まりのため 2026-07-26 開始)
        let week = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: date(year: 2026, month: 7, day: 26))! }

        XCTAssertEqual(
            lifeCalendarMonthAnchorDay(week: week, isFirstWeek: false, calendar: calendar),
            date(year: 2026, month: 8, day: 1)
        )
    }

    func testMonthAnchorDayIsNilForWeekWithoutFirstOfMonth() {
        // 月初を含まない週 (2026-08-02 開始)
        let week = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: date(year: 2026, month: 8, day: 2))! }

        XCTAssertNil(lifeCalendarMonthAnchorDay(week: week, isFirstWeek: false, calendar: calendar))
    }

    func testMonthAnchorDayFirstWeekFallsBackToWeekStart() {
        // 月初を含まない週でも最初の週なら先頭日を返す
        let week = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: date(year: 2026, month: 8, day: 2))! }

        XCTAssertEqual(
            lifeCalendarMonthAnchorDay(week: week, isFirstWeek: true, calendar: calendar),
            date(year: 2026, month: 8, day: 2)
        )
    }

    func testMonthAnchorDayFirstWeekPrefersFirstOfMonth() {
        // 最初の週が月初を含む場合は先頭日ではなく月初を返す
        let week = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: date(year: 2026, month: 7, day: 26))! }

        XCTAssertEqual(
            lifeCalendarMonthAnchorDay(week: week, isFirstWeek: true, calendar: calendar),
            date(year: 2026, month: 8, day: 1)
        )
    }

    func testDaysAreConsecutiveStartOfDays() {
        let today = date(year: 2026, month: 8, day: 13)

        let days = lifeCalendarDays(answeredDates: [], today: today, calendar: calendar)

        for (previousDay, day) in zip(days, days.dropFirst()) {
            XCTAssertEqual(calendar.date(byAdding: .day, value: 1, to: previousDay), day)
        }
        XCTAssertTrue(days.allSatisfy { calendar.startOfDay(for: $0) == $0 })
    }
}
