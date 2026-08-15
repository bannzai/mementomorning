import Foundation

/// 何日先まで発火日時を展開するか。
/// 根拠: AlarmKit はアプリをバックグラウンド wake しないため、再スケジュールは foreground 復帰時にしかできない。
/// foreground 復帰が数日空いても毎朝鳴り続けるように 7 日分を先行登録する。
/// 7 日 × (メイン 1 + バックアップ 2) = 21 件で、maxScheduledAlarmCount (30 件) 以内に収まる
let planningLookaheadDays = 7

/// メイン 1 件につき先行登録するバックアップアラームの本数。
/// 根拠: アラームのスワイプ消去は検知できない (ios-alarmkit-constraints.md) ため、保険として先に仕込む。
/// 同ルールが定める 2〜3 本の範囲のうち、件数上限 (AlarmError.maximumLimitReached) に配慮して最小の 2 本にする
let backupAlarmCount = 2

/// バックアップアラームをメインの発火時刻から何分ずつ後ろへずらすか。
/// 根拠: スワイプ消去されても二度寝に落ち切る前に追撃できる間隔にする。
/// 一方でメインを止めて回答している最中に即座に重ねて鳴らさない程度の余裕も要るため 5 分を採る
let backupAlarmIntervalMinutes = 5

/// スケジュールすべき 1 件のアラーム (エンジンの出力)
struct PlannedAlarm: Equatable {
    /// 発火予定日時
    let fireDate: Date
    /// 由来 (ScheduledAlarmOrigin.main / .backup)
    let origin: String
}

/// 現在時刻とアラーム設定から、スケジュールすべきアラーム集合を導出する。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)。
/// 現在時刻 now は必ず引数で注入する (内部で Date() を呼ばない。テスト可能性のため)。
///
/// 判定仕様:
/// - alarmSetting が nil または isEnabled == false なら空を返す
/// - now より後 lookaheadDays 日以内の hour:minute の発火日時 (毎日) のうち、
///   answeredDates (回答済みの日の 0 時の集合) に含まれる日を除いて全て展開し、
///   各発火につきメイン 1 件 + backupAlarmIntervalMinutes 分刻みのバックアップ backupAlarmCount 件を返す
///   (回答の成立 = answeredDates で当日の発火が計画から消える。回答手段には依存しない。
///   未回答時の追撃は本エンジンではなく StopAlarmIntent + SnoozeGate が担う: 無料はスヌーズ上限あり・プレミアムは無限)
/// - alarmFiredDate (直近のアラーム発火日時 = その朝の main の発火予定日時) が now と同じ日で、
///   その日が未回答なら、その main に対する未来のバックアップを計画に残す
///   (スワイプ消去はアラーム停止の Intent を通らないため、発火検知だけして全再計画するとその朝の保険が消えてしまう)
func planAlarms(
    now: Date,
    alarmSetting: AlarmSetting?,
    answeredDates: Set<Date> = [],
    alarmFiredDate: Date? = nil,
    lookaheadDays: Int = planningLookaheadDays,
    calendar: Calendar = .current
) -> [PlannedAlarm] {
    guard let alarmSetting, alarmSetting.isEnabled else { return [] }

    let occurrences = nextOccurrences(
        hour: alarmSetting.hour,
        minute: alarmSetting.minute,
        now: now,
        lookaheadDays: lookaheadDays,
        calendar: calendar
    ).filter { !answeredDates.contains(calendar.startOfDay(for: $0)) }

    let firedDayBackups: [PlannedAlarm]
    if let alarmFiredDate,
       calendar.isDate(alarmFiredDate, inSameDayAs: now),
       !answeredDates.contains(calendar.startOfDay(for: now)) {
        firedDayBackups = backupAlarms(mainFireDate: alarmFiredDate).filter { $0.fireDate > now }
    } else {
        firedDayBackups = []
    }

    return firedDayBackups + occurrences.flatMap { fireDate -> [PlannedAlarm] in
        [PlannedAlarm(fireDate: fireDate, origin: ScheduledAlarmOrigin.main)] + backupAlarms(mainFireDate: fireDate)
    }
}

/// main の発火予定日時に対するバックアップアラームの計画を返す
private func backupAlarms(mainFireDate: Date) -> [PlannedAlarm] {
    (0..<backupAlarmCount).map { index in
        PlannedAlarm(
            fireDate: mainFireDate.addingTimeInterval(TimeInterval((index + 1) * backupAlarmIntervalMinutes * 60)),
            origin: ScheduledAlarmOrigin.backup
        )
    }
}

/// now より後の直近の hour:minute を返す。
/// 夏時間の移行等で該当時刻が存在せず nextDate が nil を返した場合は 24 時間後にフォールバックする (クラッシュさせない)
func nextOccurrence(hour: Int, minute: Int, now: Date, calendar: Calendar) -> Date {
    calendar.nextDate(
        after: now,
        matching: DateComponents(hour: hour, minute: minute),
        matchingPolicy: .nextTime,
        direction: .forward
    ) ?? now.addingTimeInterval(86400)
}

/// now より後 lookaheadDays 日以内の hour:minute の発火日時を昇順で全て返す (毎日 1 回)。
/// nextOccurrence を起点に「直前の候補の直後」へカーソルを進めながら候補を辿るため、
/// 候補は毎回厳密に前進し無限ループしない
func nextOccurrences(hour: Int, minute: Int, now: Date, lookaheadDays: Int, calendar: Calendar) -> [Date] {
    let deadline = calendar.date(byAdding: .day, value: lookaheadDays, to: now) ?? now.addingTimeInterval(TimeInterval(lookaheadDays) * 86400)

    var occurrences: [Date] = []
    var cursor = now
    while true {
        let candidate = nextOccurrence(hour: hour, minute: minute, now: cursor, calendar: calendar)
        guard candidate <= deadline else { break }
        occurrences.append(candidate)
        cursor = candidate
    }
    return occurrences
}
