import XCTest
@testable import MementoMorning

/// 共有を促すダイアログの表示判定 (初回 + 2 週間おき) のテスト
final class SharePromptTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private var today: Date { calendar.date(from: DateComponents(year: 2026, month: 8, day: 19))! }

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: today)!
    }

    /// 今日の回答が無い朝には出さない (未記録でも出さない)
    func testNotPresentedWithoutTodayAnswer() {
        XCTAssertFalse(shouldPresentSharePrompt(hasTodayAnswer: false, lastPromptedDate: nil, today: today, calendar: calendar))
        XCTAssertFalse(shouldPresentSharePrompt(hasTodayAnswer: false, lastPromptedDate: daysAgo(30), today: today, calendar: calendar))
    }

    /// 初回 (一度も出していない) は今日の回答があれば出す
    func testPresentedFirstTime() {
        XCTAssertTrue(shouldPresentSharePrompt(hasTodayAnswer: true, lastPromptedDate: nil, today: today, calendar: calendar))
    }

    /// 前回の表示から 14 日未満なら出さない (同じ日・13 日前)
    func testNotPresentedWithinInterval() {
        XCTAssertFalse(shouldPresentSharePrompt(hasTodayAnswer: true, lastPromptedDate: today, today: today, calendar: calendar))
        XCTAssertFalse(shouldPresentSharePrompt(hasTodayAnswer: true, lastPromptedDate: daysAgo(1), today: today, calendar: calendar))
        XCTAssertFalse(shouldPresentSharePrompt(hasTodayAnswer: true, lastPromptedDate: daysAgo(13), today: today, calendar: calendar))
    }

    /// 前回の表示から 14 日以上経てば出す
    func testPresentedAfterInterval() {
        XCTAssertTrue(shouldPresentSharePrompt(hasTodayAnswer: true, lastPromptedDate: daysAgo(14), today: today, calendar: calendar))
        XCTAssertTrue(shouldPresentSharePrompt(hasTodayAnswer: true, lastPromptedDate: daysAgo(30), today: today, calendar: calendar))
    }

    /// 日数は暦日で数える。13 日前の夜 23:00 に表示していても、今日 (0 時基準) との差は 13 日のため出さず、
    /// 14 日前の夜 23:00 なら 14 日として出す (時刻の差 (13.04 日) では判定しない)
    func testElapsedDaysAreCountedByCalendarDay() {
        let evening13DaysAgo = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: daysAgo(13))!
        XCTAssertFalse(shouldPresentSharePrompt(hasTodayAnswer: true, lastPromptedDate: evening13DaysAgo, today: today, calendar: calendar))
        let evening14DaysAgo = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: daysAgo(14))!
        XCTAssertTrue(shouldPresentSharePrompt(hasTodayAnswer: true, lastPromptedDate: evening14DaysAgo, today: today, calendar: calendar))
    }
}
