import Foundation

extension String {
    /// 停止操作で登録した追撃アラームの UUID を保存する UserDefaults キー。
    /// foreground 復帰時の再スケジュール (全キャンセル) から発火前の追撃を保護するために使う
    static let stopIntentChaseAlarmID = "stopIntentChaseAlarmID"
    /// 追撃アラームの発火予定日時 (epoch 秒) を保存する UserDefaults キー。stopIntentChaseAlarmID と対で使う
    static let stopIntentChaseFireDate = "stopIntentChaseFireDate"
}

/// スヌーズ上限到達時に「当日分」のバックアップとみなす時間窓 (秒)。
/// バックアップの最終発火はメインの backupAlarmCount × backupAlarmIntervalMinutes = 10 分後で、
/// 追撃 (stopIntentChaseInterval × freeTierSnoozeLimit ≒ 4 分) を挟んでも上限到達は発火から十数分以内に収まる。
/// 翌日分の先行登録 (約 24 時間後) を誤って含まないよう、十分な余裕を持つ 1 時間にする
let snoozeLimitBackupCancelWindow: TimeInterval = 3600

/// 再スケジュールの全キャンセルから保護すべき追撃アラームの UUID を返す。
/// openAppWhenRun による foreground 復帰は追撃の登録直後に起きるため、無条件に全キャンセルすると
/// 追撃が一度も発火しない。発火予定が now より後 (未発火) の追撃だけを保護し、
/// 発火済み・記録なしの場合は nil (保護対象なし) を返す。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func protectedChaseAlarmID(chaseAlarmID: UUID?, chaseFireDate: Date?, now: Date) -> UUID? {
    guard let chaseAlarmID, let chaseFireDate, chaseFireDate > now else { return nil }
    return chaseAlarmID
}

/// 無料枠のスヌーズ上限に達した時にキャンセルすべき、当日分の残バックアップアラームを返す。
/// バックアップは課金状態に関係なく先行登録されるため、放置すると停止済みメインの 5 分後・10 分後にも発火し、
/// 「スヌーズ 2 回まで」の無料枠を超えてしまう。
/// snoozeLimitBackupCancelWindow 以内の未発火バックアップだけを対象にし、翌日以降の先行登録分は残す。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func backupAlarmsToCancelAtSnoozeLimit(scheduledAlarms: [ScheduledAlarm], now: Date) -> [ScheduledAlarm] {
    scheduledAlarms.filter { scheduledAlarm in
        scheduledAlarm.origin == ScheduledAlarmOrigin.backup
            && scheduledAlarm.fireDate > now
            && scheduledAlarm.fireDate <= now.addingTimeInterval(snoozeLimitBackupCancelWindow)
    }
}
