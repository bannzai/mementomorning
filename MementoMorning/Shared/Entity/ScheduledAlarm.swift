import Foundation
import SwiftData

/// AlarmKit へ登録済みのアラーム記録。
/// AlarmKit には cancelAll が無いため、登録した UUID の全列挙 → 個別キャンセルに使う。
/// アラーム設定は単一レコード運用のため、由来の設定へのリレーションは持たない。
/// 再スケジュールごとに全削除 → 全挿入する使い方のためドメインメソッドは持たない
@Model
final class ScheduledAlarm {
    /// AlarmKit の AlarmManager.schedule(id:) に渡した UUID そのもの
    @Attribute(.unique) var id: UUID
    /// 作成日時
    var createdDateTime: Date = Date.now
    /// 更新日時
    private(set) var updatedDateTime: Date = Date.now

    /// 発火予定日時
    private(set) var fireDate: Date
    /// 由来。ScheduledAlarmOrigin の値定数を使用する。
    /// enum ではなく String で保存する (マイグレーション容易性のため)
    private(set) var origin: String

    /// @Model は memberwise init を自動生成しないため明示的に定義する
    init(id: UUID = .init(), fireDate: Date, origin: String) {
        self.id = id
        self.fireDate = fireDate
        self.origin = origin
    }
}

/// ScheduledAlarm.origin の値定数
enum ScheduledAlarmOrigin {
    /// 設定時刻そのままの発火
    static let main = "main"
    /// スワイプ消去の保険として先行登録する追撃発火
    static let backup = "backup"
}
