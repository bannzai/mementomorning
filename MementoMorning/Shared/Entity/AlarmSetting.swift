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
    /// アラーム音の選択値 (AlarmSound.rawValue)。
    /// Optional のプリミティブ型で持つのは軽量マイグレーションのため (swiftdata-guidelines.md)。
    /// nil (未設定。既存レコードを含む) と未知の値の解決は resolveAlarmSound が行う (システム標準音へ倒す)
    private(set) var soundName: String?
    /// スヌーズ (追撃アラーム) の間隔の分数 (issue #135)。
    /// Optional のプリミティブ型で持つのは軽量マイグレーションのため (swiftdata-guidelines.md)。
    /// nil (未設定。既存レコードを含む) と範囲外の解決は effectiveSnoozeIntervalMinutes が行う (既定の 2 分へ倒す)
    private(set) var snoozeIntervalMinutes: Int?

    /// @Model は memberwise init を自動生成しないため明示的に定義する。
    /// snoozeLimit の既定 nil は軽量マイグレーションで既存レコードに入る値と同じ「未選択」であり、
    /// 実効値は effectiveSnoozeLimit が課金状態から決める (無料は freeTierSnoozeLimit、プレミアムは無制限)。
    /// soundName の既定 nil も同じ「未選択」で、resolveAlarmSound がシステム標準音として解決する。
    /// snoozeIntervalMinutes の既定 nil も同じ「未選択」で、effectiveSnoozeIntervalMinutes が既定の 2 分として解決する
    init(id: UUID = .init(), hour: Int, minute: Int, isEnabled: Bool = true, snoozeLimit: Int? = nil, soundName: String? = nil, snoozeIntervalMinutes: Int? = nil) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.snoozeLimit = snoozeLimit
        self.soundName = soundName
        self.snoozeIntervalMinutes = snoozeIntervalMinutes
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

    /// アラーム音を更新する (AlarmSound.rawValue を保存する)
    func setSoundName(soundName: String?) {
        self.soundName = soundName
        self.updatedDateTime = .now
    }

    /// スヌーズの間隔の分数を更新する
    func setSnoozeIntervalMinutes(snoozeIntervalMinutes: Int?) {
        self.snoozeIntervalMinutes = snoozeIntervalMinutes
        self.updatedDateTime = .now
    }
}
