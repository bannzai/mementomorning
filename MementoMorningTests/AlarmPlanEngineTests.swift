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

    func testPlanAlarmsSkipsTodayRemainderWhenAnsweredAfterFire() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        // 7:00 に発火 → 7:10 に回答が成立した状況。当日の残り (バックアップ含む) が計画から消え、翌朝から再開する
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 10)

        let planned = planAlarms(
            now: now,
            alarmSetting: alarmSetting,
            answeredDates: [calendar.startOfDay(for: now)],
            calendar: calendar
        )

        XCTAssertEqual(planned.first?.fireDate, dateTime(year: 2026, month: 8, day: 14, hour: 7, minute: 0))
    }

    func testPlanAlarmsKeepsFiredDayBackupsWhenUnanswered() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        // 7:00 に発火 (スワイプ消去で stopIntent は実行されない) → 未回答のまま 7:03 に foreground 復帰した状況。
        // 全再計画してもその朝の残バックアップ (7:05 / 7:10) は消えない
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 3)

        let planned = planAlarms(
            now: now,
            alarmSetting: alarmSetting,
            alarmFiredDate: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0),
            calendar: calendar
        )

        XCTAssertEqual(planned[0].origin, ScheduledAlarmOrigin.backup)
        XCTAssertEqual(planned[0].fireDate, dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 5))
        XCTAssertEqual(planned[1].origin, ScheduledAlarmOrigin.backup)
        XCTAssertEqual(planned[1].fireDate, dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 10))
        XCTAssertLessThanOrEqual(planned.count, maxScheduledAlarmCount)
    }

    func testPlanAlarmsDropsPastFiredDayBackups() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        // 発火から時間が経ち、その朝のバックアップ (7:05 / 7:10) が全て過去になった状況。過去の発火日時は登録しない
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 30)

        let planned = planAlarms(
            now: now,
            alarmSetting: alarmSetting,
            alarmFiredDate: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0),
            calendar: calendar
        )

        XCTAssertTrue(planned.allSatisfy { $0.fireDate > now })
        XCTAssertEqual(planned.first?.fireDate, dateTime(year: 2026, month: 8, day: 14, hour: 7, minute: 0))
    }

    func testPlanAlarmsDropsFiredDayBackupsWhenAnswered() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        // 7:00 に発火 → 7:03 に回答が成立した状況。回答の成立で当日分 (残バックアップ含む) は全て消える
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 3)

        let planned = planAlarms(
            now: now,
            alarmSetting: alarmSetting,
            answeredDates: [calendar.startOfDay(for: now)],
            alarmFiredDate: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0),
            calendar: calendar
        )

        XCTAssertEqual(planned.first?.fireDate, dateTime(year: 2026, month: 8, day: 14, hour: 7, minute: 0))
    }

    func testPlanAlarmsSkipsSkippedDate() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        // 前夜 20:00 にホームのトグルを OFF にした状況 (次の朝 = 翌日 7:00 をスキップ)。翌日だけが計画から消え、翌々日以降は残る
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 20, minute: 0)
        alarmSetting.setSkippedDate(skippedDate: dateTime(year: 2026, month: 8, day: 14, hour: 0, minute: 0))

        let planned = planAlarms(now: now, alarmSetting: alarmSetting, calendar: calendar)

        XCTAssertEqual(planned.first?.fireDate, dateTime(year: 2026, month: 8, day: 15, hour: 7, minute: 0))
        XCTAssertFalse(planned.contains { calendar.isDate($0.fireDate, inSameDayAs: dateTime(year: 2026, month: 8, day: 14, hour: 7, minute: 0)) })
        XCTAssertEqual(planned.filter { $0.origin == ScheduledAlarmOrigin.main }.count, 6)
    }

    func testPlanAlarmsIgnoresPastSkippedDate() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        // スキップした朝が過ぎた後の再スケジュール。過去の記録は解除しなくても計画に影響しない
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0)
        alarmSetting.setSkippedDate(skippedDate: dateTime(year: 2026, month: 8, day: 12, hour: 0, minute: 0))

        let planned = planAlarms(now: now, alarmSetting: alarmSetting, calendar: calendar)

        XCTAssertEqual(planned.first?.fireDate, dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 0))
        XCTAssertEqual(planned.filter { $0.origin == ScheduledAlarmOrigin.main }.count, 7)
    }

    func testNextMorningDateIsTodayWhenSettingTimeIsAfterNow() {
        let nextMorning = nextMorningDate(hour: 7, minute: 0, now: dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0), calendar: calendar)

        XCTAssertEqual(nextMorning, dateTime(year: 2026, month: 8, day: 13, hour: 0, minute: 0))
    }

    func testNextMorningDateIsTomorrowWhenSettingTimeIsBeforeNow() {
        // 夜に OFF にした時の対象は翌朝 (暦日単位にすると 0 時に解除されて翌朝が鳴ってしまう)
        let nextMorning = nextMorningDate(hour: 7, minute: 0, now: dateTime(year: 2026, month: 8, day: 13, hour: 20, minute: 0), calendar: calendar)

        XCTAssertEqual(nextMorning, dateTime(year: 2026, month: 8, day: 14, hour: 0, minute: 0))
    }

    func testIsNextMorningAlarmEnabledReturnsToTrueAfterSkippedMorningPasses() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        // 今日 7:00 をスキップ → 発火時刻を過ぎると次の朝が翌日へ進み、解除の操作なしで ON に戻る
        alarmSetting.setSkippedDate(skippedDate: dateTime(year: 2026, month: 8, day: 13, hour: 0, minute: 0))

        XCTAssertFalse(isNextMorningAlarmEnabled(now: dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0), alarmSetting: alarmSetting, calendar: calendar))
        XCTAssertTrue(isNextMorningAlarmEnabled(now: dateTime(year: 2026, month: 8, day: 13, hour: 7, minute: 30), alarmSetting: alarmSetting, calendar: calendar))
    }

    func testIsNextMorningAlarmEnabledReturnsFalseWhenDisabled() {
        // 設定画面の永続 OFF はスキップの有無に関わらず OFF
        let alarmSetting = AlarmSetting(hour: 7, minute: 0, isEnabled: false)

        XCTAssertFalse(isNextMorningAlarmEnabled(now: dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0), alarmSetting: alarmSetting, calendar: calendar))
    }

    func testPlanAlarmsIsIdempotent() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        let now = dateTime(year: 2026, month: 8, day: 13, hour: 6, minute: 0)

        let firstPlanned = planAlarms(now: now, alarmSetting: alarmSetting, calendar: calendar)
        let secondPlanned = planAlarms(now: now, alarmSetting: alarmSetting, calendar: calendar)

        XCTAssertEqual(firstPlanned, secondPlanned)
    }
}
