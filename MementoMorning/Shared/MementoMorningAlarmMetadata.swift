import AlarmKit

/// AlarmKit のアラームと自アプリのデータを対応付けるメタデータ。
/// AlarmKit の登録 UUID は ScheduledAlarm.id と同一にしているため、ここでは表示用情報のみ持つ。
/// Widget Extension を追加する場合はこの型を両ターゲットに所属させる (AlarmMetadata 型は両ターゲット必須)
struct MementoMorningAlarmMetadata: AlarmMetadata {
    /// 発火画面・Live Activity に表示するタイトル
    var title: String?
}
