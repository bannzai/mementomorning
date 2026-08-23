import Foundation

extension String {
    /// 直近にアラームが発火した日時 (epoch 秒) を保存する UserDefaults キー。
    /// AlarmKit はバックグラウンド wake せず発火自体の通知も無いため、発火の観測点である
    /// StopAlarmIntent.perform() (停止操作 = 発火済み) と Rescheduler (発火予定日時が過ぎた記録の検知) の
    /// 2 箇所から書き込み、朝の問い画面の提示判定と追撃アラームの計画に使う
    static let lastAlarmFiredDate = "lastAlarmFiredDate"
}

/// 直近のアラーム発火日時を返す。未記録なら nil
func lastAlarmFiredDate() -> Date? {
    // UserDefaults の double(forKey:) は未設定時に 0 を返すため、0 を「未記録」として扱う
    let epochSeconds = UserDefaults.standard.double(forKey: .lastAlarmFiredDate)
    guard epochSeconds > 0 else { return nil }
    return Date(timeIntervalSince1970: epochSeconds)
}

/// アラームの発火を記録する。既存の記録より古い日時では上書きしない (冪等。何度呼んでも直近の発火日時に収束する)。
/// ただし既存の記録が now より未来の場合は、時計の巻き戻し (時間変更のテスト等) で残った記録とみなして新しい発火で上書きする。
/// 未来の記録を「直近」として守り続けると、その日時を過ぎるまで実際の発火が一切記録できず、
/// 朝の問い (動画撮影) が提示されないため (issue #107)。
/// 記録が別の日へ進んだ時は連続追撃カウント (スヌーズ消費数) をリセットし、新しい朝のアラームでは無料枠を使い直せるようにする
/// (未回答のまま日を跨ぐとカウントが残り続け、翌朝以降の追撃が回答するまで封じられてしまうため)
// now の既定値 .now: 実運用の呼び出しは呼び出し時点の実時刻が現在時刻そのものであるため。テストでは固定日時を注入する
func recordAlarmFired(date: Date, now: Date = .now, calendar: Calendar = .current) {
    if let recorded = lastAlarmFiredDate() {
        // recorded が now 以前 = 通常運転の記録。直近の発火日時への収束だけを許す
        if recorded <= now {
            guard date > recorded else { return }
        }
        if !calendar.isDate(recorded, inSameDayAs: date) {
            UserDefaults.standard.removeObject(forKey: .stopIntentChaseCount)
        }
    }
    UserDefaults.standard.set(date.timeIntervalSince1970, forKey: .lastAlarmFiredDate)
}

/// 朝の問い画面を提示すべきかを判定する純粋関数。
/// 「今日アラームが発火し、まだ今日の回答 (MorningAnswer) が成立していない」間だけ true。
/// now より未来の発火記録は「まだ発火していない」(時計の巻き戻しで残った記録) として提示しない (issue #107)。
/// 回答完了の判定を answeredDates (回答済みの日の 0 時の集合) だけに依存させ、
/// テキスト入力・動画回答 (issue #24) のどちらで回答しても同じ判定で閉じるようにする
func isMorningQuestionPending(
    now: Date,
    alarmFiredDate: Date?,
    answeredDates: Set<Date>,
    calendar: Calendar = .current
) -> Bool {
    guard let alarmFiredDate, alarmFiredDate <= now, calendar.isDate(alarmFiredDate, inSameDayAs: now) else { return false }
    return !answeredDates.contains(calendar.startOfDay(for: now))
}
