import XCTest
@testable import MementoMorning

/// 朝の問いの提示判定 (isMorningQuestionPending) とアラーム発火記録 (recordAlarmFired) のテスト。
/// TEST_HOST で実アプリの UserDefaults.standard を共有するため、前後で発火記録のキーを掃除する
final class MorningQuestionGateTests: XCTestCase {
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

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: .lastAlarmFiredDate)
        UserDefaults.standard.removeObject(forKey: .stopIntentChaseCount)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: .lastAlarmFiredDate)
        UserDefaults.standard.removeObject(forKey: .stopIntentChaseCount)
        super.tearDown()
    }

    func testPendingIsFalseWhenNoAlarmFired() {
        let pending = isMorningQuestionPending(
            now: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 10),
            alarmFiredDate: nil,
            answeredDates: [],
            calendar: calendar
        )

        XCTAssertFalse(pending)
    }

    func testPendingIsTrueWhenFiredTodayAndUnanswered() {
        let pending = isMorningQuestionPending(
            now: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 10),
            alarmFiredDate: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0),
            answeredDates: [],
            calendar: calendar
        )

        XCTAssertTrue(pending)
    }

    func testPendingIsFalseWhenFiredTodayAndAnswered() {
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 10)

        let pending = isMorningQuestionPending(
            now: now,
            alarmFiredDate: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0),
            answeredDates: [calendar.startOfDay(for: now)],
            calendar: calendar
        )

        XCTAssertFalse(pending)
    }

    func testPendingIsFalseWhenFiredDateIsNotToday() {
        // 昨日発火したまま日を跨いだ場合は提示しない (問いは発火した日の朝のもの)
        let pending = isMorningQuestionPending(
            now: dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0),
            alarmFiredDate: dateTime(year: 2026, month: 8, day: 12, hour: 7, minute: 0),
            answeredDates: [],
            calendar: calendar
        )

        XCTAssertFalse(pending)
    }

    func testPendingIsFalseWhenFiredDateIsInFuture() {
        // 時計の巻き戻しで発火記録が未来に残った場合は「まだ発火していない」として提示しない (issue #107)
        let pending = isMorningQuestionPending(
            now: dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0),
            alarmFiredDate: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0),
            answeredDates: [],
            calendar: calendar
        )

        XCTAssertFalse(pending)
    }

    func testRecordAlarmFiredOverwritesFutureRecordAfterClockRollback() {
        // 時計を進めてテストした後に戻すと、発火記録が now より未来に残る状況を作る
        let futureRecord = dateTime(year: 2026, month: 8, day: 14, hour: 7, minute: 0)
        recordAlarmFired(date: futureRecord, now: futureRecord, calendar: calendar)

        // 戻した後の実際の発火は記録より古いが、未来の記録を守り続けると
        // 記録の日時を過ぎるまで朝の問い (動画撮影) が提示されないため上書きする (issue #107)
        let actualFired = dateTime(year: 2026, month: 8, day: 13, hour: 20, minute: 0)
        recordAlarmFired(date: actualFired, now: actualFired, calendar: calendar)

        XCTAssertEqual(lastAlarmFiredDate(), actualFired)
    }

    func testRecordAlarmFiredResetsChaseCountOnClockRollbackToDifferentDay() {
        // 未来の日の発火記録と、その朝で消費した無料枠が残っている状況を作る
        let futureRecord = dateTime(year: 2026, month: 8, day: 14, hour: 7, minute: 0)
        recordAlarmFired(date: futureRecord, now: futureRecord, calendar: calendar)
        UserDefaults.standard.set(2, forKey: .stopIntentChaseCount)

        // 巻き戻し後の発火は別の日のため、新しい朝として無料枠を使い直せる
        let actualFired = dateTime(year: 2026, month: 8, day: 13, hour: 20, minute: 0)
        recordAlarmFired(date: actualFired, now: actualFired, calendar: calendar)

        XCTAssertEqual(UserDefaults.standard.integer(forKey: .stopIntentChaseCount), 0)
    }

    func testRecordAlarmFiredKeepsLatestDate() {
        let older = dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0)
        let newer = dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 5)

        recordAlarmFired(date: newer, calendar: calendar)
        // 古い日時では上書きされない (発火検知が複数経路から重複しても直近の発火日時に収束する)
        recordAlarmFired(date: older, calendar: calendar)

        XCTAssertEqual(lastAlarmFiredDate(), newer)
    }

    func testRecordAlarmFiredKeepsChaseCountWithinSameDay() {
        // 同じ朝の発火記録がある状態で無料枠を消費した状況を作る
        recordAlarmFired(date: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0), calendar: calendar)
        UserDefaults.standard.set(2, forKey: .stopIntentChaseCount)

        // 同じ朝の中では無料枠の消費数を維持する (停止のたびにリセットされると上限に到達しない)
        recordAlarmFired(date: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 10), calendar: calendar)

        XCTAssertEqual(UserDefaults.standard.integer(forKey: .stopIntentChaseCount), 2)
    }

    func testRecordAlarmFiredResetsChaseCountOnNewDay() {
        recordAlarmFired(date: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0), calendar: calendar)
        // 前日の未回答で無料枠を使い切った状態
        UserDefaults.standard.set(2, forKey: .stopIntentChaseCount)

        recordAlarmFired(date: dateTime(year: 2026, month: 8, day: 14, hour: 7, minute: 0), calendar: calendar)

        // 新しい朝のアラームでは無料枠を使い直せる
        XCTAssertEqual(UserDefaults.standard.integer(forKey: .stopIntentChaseCount), 0)
    }

    func testLastAlarmFiredDateIsNilWhenNotRecorded() {
        XCTAssertNil(lastAlarmFiredDate())
    }
}
