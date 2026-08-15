import XCTest
import UserNotifications
@testable import MementoMorning

/// 夜リマインドの通知リクエスト組み立てのテスト
final class NightReminderTests: XCTestCase {
    /// 回答が無い日に使う汎用の通知本文。テストホストの言語設定によって原文 (英語) と訳文 (日本語) のどちらにも解決されるため、リテラルではなく makeContent の出力を期待値にする
    private let genericBody = NightReminder.makeContent(answerText: nil).body
    /// 引用の有無を判定するための、今朝の回答のサンプル
    private let answerText = "家族と海を見に行く"
    /// 実行マシンのタイムゾーンに結果が左右されないよう、テストで使う暦を固定する (夜リマインドはローカル時刻の 21 時に鳴るため、暦は 1 つに固定すれば足りる)
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // 実在する識別子のリテラルのため、TimeZone の生成は必ず成功する
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    /// 固定した暦の上での日時を作る
    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
    }

    func testMakeContentWithoutAnswerUsesGenericBody() {
        let content = NightReminder.makeContent(answerText: nil)

        XCTAssertFalse(content.title.isEmpty)
        XCTAssertFalse(content.body.contains(answerText), content.body)
        XCTAssertEqual(content.categoryIdentifier, "NIGHT_REMINDER")
    }

    func testMakeContentWithAnswerQuotesAnswerText() {
        let content = NightReminder.makeContent(answerText: answerText)

        XCTAssertTrue(content.body.contains(answerText), content.body)
        XCTAssertNotEqual(content.body, genericBody)
        XCTAssertEqual(content.title, NightReminder.makeContent(answerText: nil).title)
        XCTAssertEqual(content.categoryIdentifier, "NIGHT_REMINDER")
    }

    func testTruncatedAnswerTextKeepsTextWithinMaxLength() {
        XCTAssertEqual(NightReminder.truncatedAnswerText(text: answerText), answerText)
        XCTAssertEqual(
            NightReminder.truncatedAnswerText(text: String(repeating: "あ", count: NightReminder.answerTextMaxLength)).count,
            NightReminder.answerTextMaxLength
        )
    }

    func testTruncatedAnswerTextAppendsEllipsisBeyondMaxLength() {
        let truncatedText = NightReminder.truncatedAnswerText(text: String(repeating: "あ", count: NightReminder.answerTextMaxLength + 1))

        XCTAssertEqual(truncatedText.count, NightReminder.answerTextMaxLength + 1)
        XCTAssertTrue(truncatedText.hasSuffix("…"), truncatedText)
    }

    func testTruncatedAnswerTextFoldsNewlinesIntoSpaces() {
        XCTAssertEqual(NightReminder.truncatedAnswerText(text: "海を見る\n家族と話す"), "海を見る 家族と話す")
    }

    func testMakeRequestsQuotesAnswerOnlyInTodayContent() throws {
        let requests = NightReminder.makeRequests(
            todayAnswerText: answerText,
            now: try date(year: 2026, month: 8, day: 14, hour: 7, minute: 0),
            calendar: calendar
        )

        XCTAssertEqual(requests.count, NightReminder.scheduledDayCount)
        let todayRequest = try XCTUnwrap(requests.first)
        XCTAssertTrue(todayRequest.content.body.contains(answerText), todayRequest.content.body)
        for request in requests.dropFirst() {
            XCTAssertEqual(request.content.body, genericBody)
        }
    }

    func testMakeRequestsUsesDatedIdentifiersAndCategory() throws {
        let requests = NightReminder.makeRequests(
            todayAnswerText: answerText,
            now: try date(year: 2026, month: 8, day: 14, hour: 7, minute: 0),
            calendar: calendar
        )

        XCTAssertEqual(requests.first?.identifier, "night-reminder-2026-08-14")
        XCTAssertEqual(requests.last?.identifier, "night-reminder-2026-09-12")
        XCTAssertEqual(Set(requests.map(\.identifier)).count, requests.count)
        for request in requests {
            XCTAssertEqual(request.content.categoryIdentifier, "NIGHT_REMINDER")
        }
    }

    func testMakeRequestsFireOnceAtScheduledTime() throws {
        for request in NightReminder.makeRequests(
            todayAnswerText: answerText,
            now: try date(year: 2026, month: 8, day: 14, hour: 7, minute: 0),
            calendar: calendar
        ) {
            let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
            XCTAssertEqual(trigger.dateComponents.hour, 21)
            XCTAssertEqual(trigger.dateComponents.minute, 0)
            XCTAssertFalse(trigger.repeats)
        }
    }

    func testMakeRequestsSkipTodayAfterScheduledTime() throws {
        let requests = NightReminder.makeRequests(
            todayAnswerText: answerText,
            now: try date(year: 2026, month: 8, day: 14, hour: 21, minute: 30),
            calendar: calendar
        )

        XCTAssertEqual(requests.count, NightReminder.scheduledDayCount - 1)
        XCTAssertEqual(requests.first?.identifier, "night-reminder-2026-08-15")
        for request in requests {
            XCTAssertEqual(request.content.body, genericBody)
        }
    }
}
