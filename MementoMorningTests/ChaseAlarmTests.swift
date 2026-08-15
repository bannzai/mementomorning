import XCTest
@testable import MementoMorning

/// 追撃アラームの保護判定 (protectedChaseAlarmID) と
/// スヌーズ上限到達時のバックアップキャンセル対象 (backupAlarmsToCancelAtSnoozeLimit) のテスト
final class ChaseAlarmTests: XCTestCase {
    /// 基準時刻。純粋関数のテストのため任意の固定値でよい
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testProtectedChaseAlarmIDReturnsUnfiredChase() {
        let chaseAlarmID = UUID()
        XCTAssertEqual(
            protectedChaseAlarmID(chaseAlarmID: chaseAlarmID, chaseFireDate: now.addingTimeInterval(60), now: now),
            chaseAlarmID
        )
    }

    func testProtectedChaseAlarmIDIgnoresFiredChase() {
        // 発火済み (fireDate <= now) の追撃は保護しない (次の reschedule で OS 側から掃除させる)
        XCTAssertNil(protectedChaseAlarmID(chaseAlarmID: UUID(), chaseFireDate: now.addingTimeInterval(-1), now: now))
        XCTAssertNil(protectedChaseAlarmID(chaseAlarmID: UUID(), chaseFireDate: now, now: now))
    }

    func testProtectedChaseAlarmIDIgnoresMissingRecord() {
        XCTAssertNil(protectedChaseAlarmID(chaseAlarmID: nil, chaseFireDate: nil, now: now))
        XCTAssertNil(protectedChaseAlarmID(chaseAlarmID: UUID(), chaseFireDate: nil, now: now))
        XCTAssertNil(protectedChaseAlarmID(chaseAlarmID: nil, chaseFireDate: now.addingTimeInterval(60), now: now))
    }

    func testBackupAlarmsToCancelSelectsTodaysUnfiredBackups() {
        // 当日分のシナリオ: メイン発火 → 停止 2 回 (追撃消費) → 上限到達時点で残っている +5 分 / +10 分のバックアップ
        let backupIn5min = ScheduledAlarm(fireDate: now.addingTimeInterval(5 * 60), origin: ScheduledAlarmOrigin.backup)
        let backupIn10min = ScheduledAlarm(fireDate: now.addingTimeInterval(10 * 60), origin: ScheduledAlarmOrigin.backup)
        let cancelTargets = backupAlarmsToCancelAtSnoozeLimit(
            scheduledAlarms: [backupIn5min, backupIn10min],
            now: now
        )
        XCTAssertEqual(Set(cancelTargets.map(\.id)), [backupIn5min.id, backupIn10min.id])
    }

    func testBackupAlarmsToCancelExcludesMainAlarms() {
        // メインアラームは翌朝の起床装置なので上限到達でも消さない
        let mainAlarm = ScheduledAlarm(fireDate: now.addingTimeInterval(5 * 60), origin: ScheduledAlarmOrigin.main)
        XCTAssertTrue(backupAlarmsToCancelAtSnoozeLimit(scheduledAlarms: [mainAlarm], now: now).isEmpty)
    }

    func testBackupAlarmsToCancelExcludesTomorrowsBackups() {
        // 翌日以降の先行登録分 (約 24 時間後) は当日の上限到達で消さない
        let tomorrowBackup = ScheduledAlarm(fireDate: now.addingTimeInterval(24 * 3600), origin: ScheduledAlarmOrigin.backup)
        XCTAssertTrue(backupAlarmsToCancelAtSnoozeLimit(scheduledAlarms: [tomorrowBackup], now: now).isEmpty)
    }

    func testBackupAlarmsToCancelExcludesFiredBackups() {
        // 発火済み (fireDate <= now) はキャンセル不要 (OS 側に残っていても次の reschedule で掃除される)
        let firedBackup = ScheduledAlarm(fireDate: now.addingTimeInterval(-60), origin: ScheduledAlarmOrigin.backup)
        XCTAssertTrue(backupAlarmsToCancelAtSnoozeLimit(scheduledAlarms: [firedBackup], now: now).isEmpty)
    }
}
