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

    /// @Model は memberwise init を自動生成しないため明示的に定義する
    init(id: UUID = .init(), hour: Int, minute: Int, isEnabled: Bool = true) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
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
}
