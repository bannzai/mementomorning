import Foundation
import SwiftData

/// 毎朝のアラーム設定。「HH:mm に鳴らす」というユーザーの基本設定を表す。
/// 本アプリのアラームは「毎朝 1 本」だけなので単一レコードで運用する (複数アラームは持たない)。
/// 実際に AlarmKit へ登録された結果は ScheduledAlarm が持つ
@Model
final class AlarmSetting {
    /// 一意な識別子
    @Attribute(.unique) var id: UUID
    /// 作成日時
    var createdDateTime: Date = Date.now
    /// 更新日時。ドメインメソッド経由で自動更新される
    private(set) var updatedDateTime: Date = Date.now

    /// 発火時刻の時 (0-23)
    private(set) var hour: Int
    /// 発火時刻の分 (0-59)
    private(set) var minute: Int
    /// 有効フラグ。OFF の間はスケジュール対象外
    private(set) var isEnabled: Bool = true
    /// スヌーズ (追撃アラーム) の上限回数。nil は無制限。
    /// ユーザーが選んだ希望値であり、実際に効く回数は課金状態と合わせて effectiveSnoozeLimit で決める
    /// (無料は freeTierSnoozeLimit を超えない)。既存レコードには nil (無制限) として追加される
    private(set) var snoozeLimit: Int?

    /// @Model は memberwise init を自動生成しないため明示的に定義する。
    /// snoozeLimit の既定 nil は軽量マイグレーションで既存レコードに入る値と同じ「未選択」であり、
    /// 実効値は effectiveSnoozeLimit が課金状態から決める (無料は freeTierSnoozeLimit、プレミアムは無制限)
    init(id: UUID = .init(), hour: Int, minute: Int, isEnabled: Bool = true, snoozeLimit: Int? = nil) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.snoozeLimit = snoozeLimit
    }

    /// 発火時刻を更新する
    func setTime(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
        self.updatedDateTime = .now
    }

    /// 有効フラグを更新する
    func setIsEnabled(isEnabled: Bool) {
        self.isEnabled = isEnabled
        self.updatedDateTime = .now
    }

    /// スヌーズの上限回数を更新する (nil = 無制限)
    func setSnoozeLimit(snoozeLimit: Int?) {
        self.snoozeLimit = snoozeLimit
        self.updatedDateTime = .now
    }
}
