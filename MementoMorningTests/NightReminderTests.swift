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

    /// 時刻設定が 1 件も無い既存ユーザーと同じ、既定の 1 本 (21:00) の時刻リスト
    private let defaultTimes = [DateComponents(hour: 21, minute: 0)]
    /// プレミアムで 3 本登録した時の時刻リスト
    private let threeTimes = [
        DateComponents(hour: 21, minute: 0),
        DateComponents(hour: 22, minute: 30),
        DateComponents(hour: 23, minute: 45),
    ]

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
            times: defaultTimes,
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
            times: defaultTimes,
            todayAnswerText: answerText,
            now: try date(year: 2026, month: 8, day: 14, hour: 7, minute: 0),
            calendar: calendar
        )

        XCTAssertEqual(requests.first?.identifier, "night-reminder-2026-08-14-2100")
        XCTAssertEqual(requests.last?.identifier, "night-reminder-2026-09-02-2100")
        XCTAssertEqual(Set(requests.map(\.identifier)).count, requests.count)
        for request in requests {
            XCTAssertTrue(request.identifier.hasPrefix(NightReminder.requestIdentifierPrefix), request.identifier)
            XCTAssertEqual(request.content.categoryIdentifier, "NIGHT_REMINDER")
        }
    }

    func testMakeRequestsFireOnceAtScheduledTime() throws {
        for request in NightReminder.makeRequests(
            times: defaultTimes,
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
            times: defaultTimes,
            todayAnswerText: answerText,
            now: try date(year: 2026, month: 8, day: 14, hour: 21, minute: 30),
            calendar: calendar
        )

        XCTAssertEqual(requests.count, NightReminder.scheduledDayCount - 1)
        XCTAssertEqual(requests.first?.identifier, "night-reminder-2026-08-15-2100")
        for request in requests {
            XCTAssertEqual(request.content.body, genericBody)
        }
    }

    func testMakeRequestsCoverEveryTimeOfEveryDay() throws {
        let requests = NightReminder.makeRequests(
            times: threeTimes,
            todayAnswerText: answerText,
            now: try date(year: 2026, month: 8, day: 14, hour: 7, minute: 0),
            calendar: calendar
        )

        XCTAssertEqual(requests.count, threeTimes.count * NightReminder.scheduledDayCount)
        XCTAssertEqual(Set(requests.map(\.identifier)).count, requests.count)
        XCTAssertEqual(
            requests.prefix(threeTimes.count).map(\.identifier),
            ["night-reminder-2026-08-14-2100", "night-reminder-2026-08-14-2230", "night-reminder-2026-08-14-2345"]
        )
        // 当日分は本数によらず全て今朝の回答を引用し、翌日以降は汎用文言にする
        for request in requests.prefix(threeTimes.count) {
            XCTAssertTrue(request.content.body.contains(answerText), request.content.body)
        }
        for request in requests.dropFirst(threeTimes.count) {
            XCTAssertEqual(request.content.body, genericBody)
        }
        XCTAssertEqual(
            try XCTUnwrap(requests[1].trigger as? UNCalendarNotificationTrigger).dateComponents.minute,
            30
        )
    }

    func testMakeRequestsSkipOnlyPassedTimesOfToday() throws {
        let requests = NightReminder.makeRequests(
            times: threeTimes,
            todayAnswerText: answerText,
            now: try date(year: 2026, month: 8, day: 14, hour: 22, minute: 40),
            calendar: calendar
        )

        // 当日は 23:45 の 1 本だけが残る (21:00 と 22:30 は過ぎている)
        XCTAssertEqual(requests.count, threeTimes.count * NightReminder.scheduledDayCount - 2)
        XCTAssertEqual(requests.first?.identifier, "night-reminder-2026-08-14-2345")
        XCTAssertTrue(try XCTUnwrap(requests.first).content.body.contains(answerText))
    }

    /// 件数管理は実行時チェックではなく定数設計で行う (.claude/rules/ios-alarmkit-constraints.md)。
    /// 1 日の最大本数 × 先読み日数 + デバッグ用の 1 本が保留中通知の上限に収まることを定数だけで確かめる
    func testScheduledRequestCountFitsPendingNotificationLimit() {
        XCTAssertLessThanOrEqual(
            maxNightReminderCount * NightReminder.scheduledDayCount + 1,
            NightReminder.pendingNotificationLimit
        )
    }

    func testScheduledRequestCountAtMaxTimesFitsPendingNotificationLimit() throws {
        let requests = NightReminder.makeRequests(
            times: (0..<maxNightReminderCount).map { DateComponents(hour: 21 + $0, minute: 0) },
            todayAnswerText: nil,
            now: try date(year: 2026, month: 8, day: 14, hour: 7, minute: 0),
            calendar: calendar
        )

        XCTAssertLessThanOrEqual(requests.count + 1, NightReminder.pendingNotificationLimit)
    }

    func testEffectiveNightReminderTimesFallBackToDefaultWhenUnset() {
        XCTAssertEqual(
            effectiveNightReminderTimes(times: [], isPremium: false),
            [DateComponents(hour: defaultNightReminderHour, minute: defaultNightReminderMinute)]
        )
        XCTAssertEqual(
            effectiveNightReminderTimes(times: [], isPremium: true),
            [DateComponents(hour: defaultNightReminderHour, minute: defaultNightReminderMinute)]
        )
    }

    func testEffectiveNightReminderTimesKeepOnlyFirstWhenFree() {
        // プレミアム失効中も保存済みの 2・3 本目は残る (実効値から外れるだけ)
        XCTAssertEqual(effectiveNightReminderTimes(times: threeTimes, isPremium: false), Array(threeTimes.prefix(freeTierNightReminderCount)))
        XCTAssertEqual(effectiveNightReminderTimes(times: [DateComponents(hour: 22, minute: 15)], isPremium: false), [DateComponents(hour: 22, minute: 15)])
    }

    func testEffectiveNightReminderTimesKeepAllWhenPremium() {
        XCTAssertEqual(effectiveNightReminderTimes(times: threeTimes, isPremium: true), threeTimes)
    }

    func testIsNightReminderSelectableFollowsPremiumAndMaxCount() {
        XCTAssertTrue(isNightReminderSelectable(index: 0, isPremium: false))
        XCTAssertFalse(isNightReminderSelectable(index: freeTierNightReminderCount, isPremium: false))
        XCTAssertTrue(isNightReminderSelectable(index: maxNightReminderCount - 1, isPremium: true))
        XCTAssertFalse(isNightReminderSelectable(index: maxNightReminderCount, isPremium: true))
    }
}
