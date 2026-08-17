import XCTest
@testable import MementoMorning

/// 「今日の目標」Live Activity の staleDate 計算 (todayAnswerActivityStaleDate) のテスト
final class TodayAnswerLiveActivityTests: XCTestCase {
    /// タイムゾーンを固定したカレンダー
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    /// 固定タイムゾーン上の日時を作る
    private func dateTime(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testStaleDateIsNextMidnightForMorningAnswer() {
        XCTAssertEqual(
            todayAnswerActivityStaleDate(now: dateTime(year: 2026, month: 8, day: 17, hour: 7, minute: 30), calendar: calendar),
            dateTime(year: 2026, month: 8, day: 18, hour: 0, minute: 0)
        )
    }

    func testStaleDateIsNextMidnightJustBeforeDayChange() {
        XCTAssertEqual(
            todayAnswerActivityStaleDate(now: dateTime(year: 2026, month: 8, day: 17, hour: 23, minute: 59), calendar: calendar),
            dateTime(year: 2026, month: 8, day: 18, hour: 0, minute: 0)
        )
    }

    func testStaleDateCrossesMonthBoundary() {
        XCTAssertEqual(
            todayAnswerActivityStaleDate(now: dateTime(year: 2026, month: 8, day: 31, hour: 9, minute: 0), calendar: calendar),
            dateTime(year: 2026, month: 9, day: 1, hour: 0, minute: 0)
        )
    }

    func testDisplayTextKeepsShortAnswer() {
        XCTAssertEqual(todayAnswerActivityDisplayText(text: "家族と海を見に行く"), "家族と海を見に行く")
    }

    func testDisplayTextTruncatesLongAnswer() {
        let displayText = todayAnswerActivityDisplayText(text: String(repeating: "あ", count: todayAnswerActivityTextLimit + 1))

        XCTAssertEqual(displayText, String(repeating: "あ", count: todayAnswerActivityTextLimit))
    }
}
