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

    /// text を格納した ContentState の JSON エンコード後のバイト数 (検証対象と同じ判定基準)
    private func encodedByteCount(text: String) -> Int {
        try! JSONEncoder().encode(TodayAnswerActivityAttributes.ContentState(text: text)).count
    }

    func testDisplayTextTruncatesLongAnswerWithinEncodedLimit() {
        let displayText = todayAnswerActivityDisplayText(text: String(repeating: "あ", count: 1000))

        XCTAssertFalse(displayText.isEmpty)
        XCTAssertTrue(displayText.allSatisfy { $0 == "あ" })
        XCTAssertLessThanOrEqual(encodedByteCount(text: displayText), todayAnswerActivityContentStateByteLimit)
    }

    func testDisplayTextDoesNotSplitMultiScalarEmoji() {
        // 家族絵文字は 1 Character が複数 Unicode scalar (25 バイト)。文字数ではなくバイト数で制限され、絵文字の途中で壊れない
        let familyEmoji = "👨‍👩‍👧‍👦"
        let displayText = todayAnswerActivityDisplayText(text: String(repeating: familyEmoji, count: 300))

        XCTAssertFalse(displayText.isEmpty)
        XCTAssertTrue(displayText.allSatisfy { String($0) == familyEmoji })
        XCTAssertLessThanOrEqual(encodedByteCount(text: displayText), todayAnswerActivityContentStateByteLimit)
    }

    func testDisplayTextTruncatesEscapedCharactersWithinEncodedLimit() {
        // 引用符は JSON エスケープで 2 バイトになる。生の UTF-8 バイト数ではなくエンコード後サイズで上限内に収まる
        let displayText = todayAnswerActivityDisplayText(text: String(repeating: "\"", count: 2048))

        XCTAssertFalse(displayText.isEmpty)
        XCTAssertLessThanOrEqual(encodedByteCount(text: displayText), todayAnswerActivityContentStateByteLimit)
    }
}
