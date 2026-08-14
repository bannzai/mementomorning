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

/// アラームの発火を記録する。既存の記録より古い日時では上書きしない (冪等。何度呼んでも直近の発火日時に収束する)
func recordAlarmFired(date: Date) {
    if let recorded = lastAlarmFiredDate(), recorded >= date { return }
    UserDefaults.standard.set(date.timeIntervalSince1970, forKey: .lastAlarmFiredDate)
}

/// 朝の問い画面を提示すべきかを判定する純粋関数。
/// 「今日アラームが発火し、まだ今日の回答 (MorningAnswer) が成立していない」間だけ true。
/// 回答完了の判定を answeredDates (回答済みの日の 0 時の集合) だけに依存させ、
/// テキスト入力・動画回答 (issue #24) のどちらで回答しても同じ判定で閉じるようにする
func isMorningQuestionPending(
    now: Date,
    alarmFiredDate: Date?,
    answeredDates: Set<Date>,
    calendar: Calendar = .current
) -> Bool {
    guard let alarmFiredDate, calendar.isDate(alarmFiredDate, inSameDayAs: now) else { return false }
    return !answeredDates.contains(calendar.startOfDay(for: now))
}
