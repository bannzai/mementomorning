import XCTest
@testable import MementoMorning

/// monthCalendarCells / startOfMonth のテスト
final class MonthCalendarDatesTests: XCTestCase {
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

    func testStartOfMonthReturnsFirstDay() {
        XCTAssertEqual(
            startOfMonth(date: date(year: 2026, month: 8, day: 23), calendar: calendar),
            date(year: 2026, month: 8, day: 1)
        )
        XCTAssertEqual(
            startOfMonth(date: date(year: 2026, month: 8, day: 1), calendar: calendar),
            date(year: 2026, month: 8, day: 1)
        )
    }

    func testCellsStartWithLeadingEmptyCells() {
        // 2026-08-01 は土曜 (日曜始まりで列 6) のため、先頭に 6 マスの空きが入る
        let cells = monthCalendarCells(month: date(year: 2026, month: 8, day: 23), calendar: calendar)

        XCTAssertEqual(Array(cells.prefix(6)), [nil, nil, nil, nil, nil, nil])
        XCTAssertEqual(cells[6], date(year: 2026, month: 8, day: 1))
    }

    func testCellsContainAllDaysOfMonthInOrder() {
        let cells = monthCalendarCells(month: date(year: 2026, month: 8, day: 1), calendar: calendar)

        let days = cells.compactMap { $0 }
        XCTAssertEqual(days.count, 31)
        XCTAssertEqual(days.first, date(year: 2026, month: 8, day: 1))
        XCTAssertEqual(days.last, date(year: 2026, month: 8, day: 31))
        for (previousDay, day) in zip(days, days.dropFirst()) {
            XCTAssertEqual(calendar.date(byAdding: .day, value: 1, to: previousDay), day)
        }
    }

    func testCellCountIsMultipleOfSeven() {
        // 2026-08 は先頭 6 マス + 31 日 = 37 → 42 マス (6 週) に切り上がる
        XCTAssertEqual(monthCalendarCells(month: date(year: 2026, month: 8, day: 1), calendar: calendar).count, 42)
        // 2026-02 は日曜始まり (先頭の空きなし) の 28 日 = ちょうど 4 週
        XCTAssertEqual(monthCalendarCells(month: date(year: 2026, month: 2, day: 1), calendar: calendar).count, 28)
    }

    func testMondayFirstCalendarShiftsLeadingCells() {
        // 月曜始まりでは 2026-08-01 (土) の手前の空きは 5 マスになる
        var mondayFirstCalendar = calendar
        mondayFirstCalendar.firstWeekday = 2

        let cells = monthCalendarCells(month: date(year: 2026, month: 8, day: 1), calendar: mondayFirstCalendar)

        XCTAssertEqual(Array(cells.prefix(5)), [nil, nil, nil, nil, nil])
        XCTAssertEqual(cells[5], date(year: 2026, month: 8, day: 1))
    }

    func testTrailingCellsArePaddedWithNil() {
        // 2026-08 の末尾は 31 日 (月曜、列 1) の後に 5 マスの空きが入る
        let cells = monthCalendarCells(month: date(year: 2026, month: 8, day: 1), calendar: calendar)

        XCTAssertEqual(Array(cells.suffix(5)), [nil, nil, nil, nil, nil])
    }
}
