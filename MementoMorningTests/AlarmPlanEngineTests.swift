import XCTest
@testable import MementoMorning

/// planAlarms のテスト。now と Calendar を固定値で注入し、実行環境の時刻・タイムゾーンに結果が依存しないようにする
final class AlarmPlanEngineTests: XCTestCase {
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

    func testPlanAlarmsReturnsEmptyWhenAlarmSettingIsNil() {
        let planned = planAlarms(now: dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0), alarmSetting: nil, calendar: calendar)

        XCTAssertTrue(planned.isEmpty)
    }

    func testPlanAlarmsReturnsEmptyWhenDisabled() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0, isEnabled: false)

        let planned = planAlarms(now: dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0), alarmSetting: alarmSetting, calendar: calendar)

        XCTAssertTrue(planned.isEmpty)
    }

    func testFirstMainAlarmIsTodayWhenSettingTimeIsAfterNow() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)

        let planned = planAlarms(now: dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0), alarmSetting: alarmSetting, calendar: calendar)

        XCTAssertEqual(planned.first?.origin, ScheduledAlarmOrigin.main)
        XCTAssertEqual(planned.first?.fireDate, dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0))
    }

    func testFirstMainAlarmIsTomorrowWhenSettingTimeIsBeforeNow() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)

        let planned = planAlarms(now: dateTime(year: 2026, month: 8, day: 13, hour: 8, minute: 0), alarmSetting: alarmSetting, calendar: calendar)

        XCTAssertEqual(planned.first?.origin, ScheduledAlarmOrigin.main)
        XCTAssertEqual(planned.first?.fireDate, dateTime(year: 2026, month: 8, day: 14, hour: 7, minute: 0))
    }

    func testPlanAlarmsCoversLookaheadDaysWithBackups() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)

        let planned = planAlarms(now: dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0), alarmSetting: alarmSetting, calendar: calendar)

        // 定数から導かず件数を直接書く (定数を変えた時にテストが黙って追従せず、件数キャップの前提崩れに気づけるようにする)
        XCTAssertEqual(planned.filter { $0.origin == ScheduledAlarmOrigin.main }.count, 7)
        XCTAssertEqual(planned.filter { $0.origin == ScheduledAlarmOrigin.backup }.count, 14)
        XCTAssertEqual(planned.count, 21)
        XCTAssertLessThanOrEqual(planned.count, maxScheduledAlarmCount)
    }

    func testBackupAlarmsFollowEachMainAlarmByInterval() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)

        let planned = planAlarms(now: dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0), alarmSetting: alarmSetting, calendar: calendar)

        let mainIndices = planned.indices.filter { planned[$0].origin == ScheduledAlarmOrigin.main }
        for mainIndex in mainIndices {
            let mainFireDate = planned[mainIndex].fireDate
            for backupIndex in 1...backupAlarmCount {
                let backup = planned[mainIndex + backupIndex]
                XCTAssertEqual(backup.origin, ScheduledAlarmOrigin.backup)
                XCTAssertEqual(backup.fireDate, mainFireDate.addingTimeInterval(TimeInterval(backupIndex * backupAlarmIntervalMinutes * 60)))
            }
        }
    }

    func testPlanAlarmsSkipsAnsweredDay() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        // 6:00 に回答済み (アラーム発火前の先回りの回答) → 今日 7:00 は鳴らさず明日から計画する
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0)
        let today = calendar.startOfDay(for: now)

        let planned = planAlarms(now: now, alarmSetting: alarmSetting, answeredDates: [today], calendar: calendar)

        XCTAssertEqual(planned.first?.fireDate, dateTime(year: 2026, month: 8, day: 14, hour: 7, minute: 0))
        XCTAssertFalse(planned.contains { calendar.startOfDay(for: $0.fireDate) == today })
    }

    func testPlanAlarmsAddsChasesWhenFiredTodayAndUnanswered() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        // 7:00 に発火 → 未回答のまま 7:10 に foreground 復帰した状況
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 10)

        let planned = planAlarms(
            now: now,
            alarmSetting: alarmSetting,
            alarmFiredDate: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0),
            calendar: calendar
        )

        let chases = planned.filter { $0.origin == ScheduledAlarmOrigin.chase }
        // 定数から導かず件数を直接書く (定数を変えた時にテストが黙って追従せず、件数キャップの前提崩れに気づけるようにする)
        XCTAssertEqual(chases.count, 3)
        XCTAssertEqual(chases.map(\.fireDate), [
            dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 12),
            dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 14),
            dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 16),
        ])
        XCTAssertLessThanOrEqual(planned.count, maxScheduledAlarmCount)
    }

    func testPlanAlarmsAddsNoChaseWhenAnswered() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        // 7:00 に発火 → 7:10 に回答が成立した状況。当日の全アラームが計画から消える
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 10)

        let planned = planAlarms(
            now: now,
            alarmSetting: alarmSetting,
            answeredDates: [calendar.startOfDay(for: now)],
            alarmFiredDate: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0),
            calendar: calendar
        )

        XCTAssertFalse(planned.contains { $0.origin == ScheduledAlarmOrigin.chase })
        XCTAssertEqual(planned.first?.fireDate, dateTime(year: 2026, month: 8, day: 14, hour: 7, minute: 0))
    }

    func testPlanAlarmsAddsNoChaseWhenFiredDateIsNotToday() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        // 昨日発火したが未回答のまま日を跨いだ状況。追撃は当日限りで持ち越さない
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0)

        let planned = planAlarms(
            now: now,
            alarmSetting: alarmSetting,
            alarmFiredDate: dateTime(year: 2026, month: 8, day: 12, hour: 7, minute: 0),
            calendar: calendar
        )

        XCTAssertFalse(planned.contains { $0.origin == ScheduledAlarmOrigin.chase })
    }

    func testPlanAlarmsAddsNoChaseWhenDisabled() {
        // 発火後でもアラーム設定を OFF にしたら追撃も止まる (ユーザーの明示的な停止手段)
        let alarmSetting = AlarmSetting(hour: 7, minute: 0, isEnabled: false)
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 10)

        let planned = planAlarms(
            now: now,
            alarmSetting: alarmSetting,
            alarmFiredDate: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0),
            calendar: calendar
        )

        XCTAssertTrue(planned.isEmpty)
    }

    func testPlanAlarmsIsIdempotent() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0)

        let firstPlanned = planAlarms(now: now, alarmSetting: alarmSetting, calendar: calendar)
        let secondPlanned = planAlarms(now: now, alarmSetting: alarmSetting, calendar: calendar)

        XCTAssertEqual(firstPlanned, secondPlanned)
    }
}
