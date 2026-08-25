import XCTest
@testable import MementoMorning

/// 設定画面の自動保存の変更判定 (hasAlarmSettingChanges) のテスト。
/// onAppear の復元が起こす onChange (実変更なし) では保存されず、実変更だけが保存の対象になることと、
/// プレミアム失効中に隠れている希望値 (スヌーズ回数・2 本目以降のリマインド) を変更として扱わないことを確認する
final class AlarmSettingAutoSaveTests: XCTestCase {
    /// onAppear の復元直後 (入力値 = 保存済みの実効値) は変更なしと判定する
    func testRestoredInputHasNoChanges() {
        XCTAssertFalse(hasAlarmSettingChanges(
            hour: 7,
            minute: 0,
            isEnabled: true,
            snoozeLimit: freeTierSnoozeLimit,
            // 保存済みが 0 件の時、画面には既定の 1 本 (21:00) が復元される
            alarmSound: .systemDefault,
            nightReminderTimes: [DateComponents(hour: defaultNightReminderHour, minute: defaultNightReminderMinute)],
            alarmSetting: AlarmSetting(hour: 7, minute: 0),
            storedNightReminderTimes: [],
            isPremium: false
        ))
    }

    /// 時刻・ON/OFF の変更は変更ありと判定する
    func testTimeAndEnabledChanges() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        // 復元後の入力値 (実効値) をベースに 1 項目ずつ変える
        let restoredNightReminderTimes = [DateComponents(hour: defaultNightReminderHour, minute: defaultNightReminderMinute)]
        XCTAssertTrue(hasAlarmSettingChanges(
            hour: 8, minute: 0, isEnabled: true, snoozeLimit: freeTierSnoozeLimit,
            alarmSound: .systemDefault,
            nightReminderTimes: restoredNightReminderTimes,
            alarmSetting: alarmSetting, storedNightReminderTimes: [], isPremium: false
        ))
        XCTAssertTrue(hasAlarmSettingChanges(
            hour: 7, minute: 30, isEnabled: true, snoozeLimit: freeTierSnoozeLimit,
            alarmSound: .systemDefault,
            nightReminderTimes: restoredNightReminderTimes,
            alarmSetting: alarmSetting, storedNightReminderTimes: [], isPremium: false
        ))
        XCTAssertTrue(hasAlarmSettingChanges(
            hour: 7, minute: 0, isEnabled: false, snoozeLimit: freeTierSnoozeLimit,
            alarmSound: .systemDefault,
            nightReminderTimes: restoredNightReminderTimes,
            alarmSetting: alarmSetting, storedNightReminderTimes: [], isPremium: false
        ))
    }

    /// スヌーズ回数は実効値で比較する。プレミアム失効中に残った希望値 (無料枠超) は、
    /// 実効値 (無料枠) のままなら変更として扱わず、別の回数を選んだ時だけ変更ありにする
    func testSnoozeLimitComparesEffectiveValue() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0, snoozeLimit: 10)
        let restoredNightReminderTimes = [DateComponents(hour: defaultNightReminderHour, minute: defaultNightReminderMinute)]
        // 復元された実効値 (無料枠 2 回) のままは変更なし = 希望値 10 を上書きしない
        XCTAssertFalse(hasAlarmSettingChanges(
            hour: 7, minute: 0, isEnabled: true, snoozeLimit: freeTierSnoozeLimit,
            alarmSound: .systemDefault,
            nightReminderTimes: restoredNightReminderTimes,
            alarmSetting: alarmSetting, storedNightReminderTimes: [], isPremium: false
        ))
        XCTAssertTrue(hasAlarmSettingChanges(
            hour: 7, minute: 0, isEnabled: true, snoozeLimit: 1,
            alarmSound: .systemDefault,
            nightReminderTimes: restoredNightReminderTimes,
            alarmSetting: alarmSetting, storedNightReminderTimes: [], isPremium: false
        ))
        // プレミアムなら希望値 10 がそのまま実効値になり、無制限 (nil) への変更は変更あり
        XCTAssertFalse(hasAlarmSettingChanges(
            hour: 7, minute: 0, isEnabled: true, snoozeLimit: 10,
            alarmSound: .systemDefault,
            nightReminderTimes: restoredNightReminderTimes,
            alarmSetting: alarmSetting, storedNightReminderTimes: [], isPremium: true
        ))
        XCTAssertTrue(hasAlarmSettingChanges(
            hour: 7, minute: 0, isEnabled: true, snoozeLimit: nil,
            alarmSound: .systemDefault,
            nightReminderTimes: restoredNightReminderTimes,
            alarmSetting: alarmSetting, storedNightReminderTimes: [], isPremium: true
        ))
    }

    /// 夜リマインドは実効値で比較する。無料で隠れている 2 本目は変更として扱わず、
    /// 表示中の 1 本目の時刻変更だけを変更ありにする
    func testNightReminderComparesEffectiveTimes() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        let storedNightReminderTimes = [DateComponents(hour: 21, minute: 0), DateComponents(hour: 22, minute: 0)]
        // 無料の復元値は 1 本目だけ。2 本目が保存されていても変更なし = 隠れた 2 本目を消さない
        XCTAssertFalse(hasAlarmSettingChanges(
            hour: 7, minute: 0, isEnabled: true, snoozeLimit: freeTierSnoozeLimit,
            alarmSound: .systemDefault,
            nightReminderTimes: [DateComponents(hour: 21, minute: 0)],
            alarmSetting: alarmSetting, storedNightReminderTimes: storedNightReminderTimes, isPremium: false
        ))
        XCTAssertTrue(hasAlarmSettingChanges(
            hour: 7, minute: 0, isEnabled: true, snoozeLimit: freeTierSnoozeLimit,
            alarmSound: .systemDefault,
            nightReminderTimes: [DateComponents(hour: 21, minute: 15)],
            alarmSetting: alarmSetting, storedNightReminderTimes: storedNightReminderTimes, isPremium: false
        ))
        // プレミアムは全本数を比較する (スヌーズの入力は保存済み nil のプレミアム実効値 = 無制限に合わせる)
        XCTAssertFalse(hasAlarmSettingChanges(
            hour: 7, minute: 0, isEnabled: true, snoozeLimit: nil,
            alarmSound: .systemDefault,
            nightReminderTimes: storedNightReminderTimes,
            alarmSetting: alarmSetting, storedNightReminderTimes: storedNightReminderTimes, isPremium: true
        ))
        XCTAssertTrue(hasAlarmSettingChanges(
            hour: 7, minute: 0, isEnabled: true, snoozeLimit: nil,
            alarmSound: .systemDefault,
            nightReminderTimes: [DateComponents(hour: 21, minute: 0)],
            alarmSetting: alarmSetting, storedNightReminderTimes: storedNightReminderTimes, isPremium: true
        ))
    }

    /// アラーム音は保存済みの soundName の解決値と比較する。
    /// 未設定 (nil) はシステム標準音と等しく変更なし、別の音を選んだ時だけ変更ありにする
    func testAlarmSoundChanges() {
        let alarmSetting = AlarmSetting(hour: 7, minute: 0)
        let restoredNightReminderTimes = [DateComponents(hour: defaultNightReminderHour, minute: defaultNightReminderMinute)]
        XCTAssertFalse(hasAlarmSettingChanges(
            hour: 7, minute: 0, isEnabled: true, snoozeLimit: freeTierSnoozeLimit,
            alarmSound: .systemDefault,
            nightReminderTimes: restoredNightReminderTimes,
            alarmSetting: alarmSetting, storedNightReminderTimes: [], isPremium: false
        ))
        XCTAssertTrue(hasAlarmSettingChanges(
            hour: 7, minute: 0, isEnabled: true, snoozeLimit: freeTierSnoozeLimit,
            alarmSound: .gentleChime,
            nightReminderTimes: restoredNightReminderTimes,
            alarmSetting: alarmSetting, storedNightReminderTimes: [], isPremium: false
        ))
        // 保存済みの音と同じ選択は変更なし
        XCTAssertFalse(hasAlarmSettingChanges(
            hour: 7, minute: 0, isEnabled: true, snoozeLimit: freeTierSnoozeLimit,
            alarmSound: .morningBell,
            nightReminderTimes: restoredNightReminderTimes,
            alarmSetting: AlarmSetting(hour: 7, minute: 0, soundName: AlarmSound.morningBell.rawValue),
            storedNightReminderTimes: [], isPremium: false
        ))
    }

    /// 保存済みが無い時は常に変更ありと判定する (onChange の発火 = ユーザーの実操作のため)
    func testNoStoredSettingAlwaysHasChanges() {
        XCTAssertTrue(hasAlarmSettingChanges(
            hour: 7, minute: 0, isEnabled: true, snoozeLimit: freeTierSnoozeLimit,
            alarmSound: .systemDefault,
            nightReminderTimes: [DateComponents(hour: defaultNightReminderHour, minute: defaultNightReminderMinute)],
            alarmSetting: nil, storedNightReminderTimes: [], isPremium: false
        ))
    }
}
