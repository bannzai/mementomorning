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

    func testRecordAlarmFiredKeepsLatestDate() {
        let older = dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0)
        let newer = dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 5)

        recordAlarmFired(date: newer, calendar: calendar)
        // 古い日時では上書きされない (発火検知が複数経路から重複しても直近の発火日時に収束する)
        recordAlarmFired(date: older, calendar: calendar)

        XCTAssertEqual(lastAlarmFiredDate(), newer)
    }

    func testRecordAlarmFiredKeepsChaseCountWithinSameDay() {
        UserDefaults.standard.set(2, forKey: .stopIntentChaseCount)

        recordAlarmFired(date: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0), calendar: calendar)
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
