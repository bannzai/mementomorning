import Foundation
import SwiftData

/// 1 日に登録できる夜リマインドの最大本数。
/// 根拠: 保留中の通知は最大 64 件 (NightReminder.pendingNotificationLimit) という制約に対し、
/// maxNightReminderCount × NightReminder.scheduledDayCount + デバッグ用 1 本が上限に収まる本数にする
let maxNightReminderCount = 3

/// 無料枠で有効になる夜リマインドの本数。
/// 根拠: documents/PROJECT.md の課金設計「無料: 夜リマインド 1 本 / プレミアム: リマインドカスタム」
let freeTierNightReminderCount = 1

/// 設定が 1 件も無い時に使う既定の通知時刻 (時)。
/// 根拠: 時刻設定を導入する前の固定値と同じ 21:00 にして、既存ユーザーのリマインド時刻を変えない
let defaultNightReminderHour = 21
/// 設定が 1 件も無い時に使う既定の通知時刻 (分)。根拠は defaultNightReminderHour と同じ
let defaultNightReminderMinute = 0

/// 何本目 (0 始まり) の夜リマインドまで現在の課金状態で使えるか。
/// 無料は先頭 freeTierNightReminderCount 本だけ使え、それ以降と最大本数の超過はプレミアムでのみ使える。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func isNightReminderSelectable(index: Int, isPremium: Bool) -> Bool {
    guard index < maxNightReminderCount else { return false }
    return isPremium || index < freeTierNightReminderCount
}

/// 保存済みの通知時刻と課金状態から、実際に登録する通知時刻を決める。
/// 設定が 1 件も無い時は既定の 1 本 (21:00) に倒し、時刻設定を導入する前と同じ振る舞いにする。
/// 無料では先頭 freeTierNightReminderCount 本だけを残す (プレミアム失効中も保存済みの 2・3 本目は消さず、有効にしないだけにする)。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func effectiveNightReminderTimes(times: [DateComponents], isPremium: Bool) -> [DateComponents] {
    guard !times.isEmpty else {
        return [DateComponents(hour: defaultNightReminderHour, minute: defaultNightReminderMinute)]
    }
    return Array(times.prefix(isPremium ? maxNightReminderCount : freeTierNightReminderCount))
}

/// 夜リマインド (「守れてますか?」) を鳴らす時刻。1 日に最大 maxNightReminderCount 本まで登録でき、
/// 1 件も無い時は既定の 1 本 (21:00) として振る舞う。時刻の変更は無料、2 本目以降の追加はプレミアム
@Model
final class NightReminderSetting {
    /// 一意な識別子
    @Attribute(.unique) var id: UUID
    /// 作成日時。ユーザーが追加した順 = 画面上の表示順であり、無料枠で有効になる 1 本目の判定にも使う
    var createdDateTime: Date = Date.now
    /// 更新日時。ドメインメソッド経由で自動更新される
    private(set) var updatedDateTime: Date = Date.now

    /// 通知時刻の時 (0-23)
    private(set) var hour: Int
    /// 通知時刻の分 (0-59)
    private(set) var minute: Int

    /// @Model は memberwise init を自動生成しないため明示的に定義する
    init(id: UUID = .init(), hour: Int, minute: Int) {
        self.id = id
        self.hour = hour
        self.minute = minute
    }

    /// 通知時刻を更新する
    func setTime(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
        self.updatedDateTime = .now
    }

    /// 保存済みの夜リマインド設定を登録順 (createdDateTime 昇順) に取得する。
    /// 取得の失敗を空配列にせず throw するのは、呼び出し側が「取得に失敗した」と「未設定」を区別できるようにするため
    static func all(modelContext: ModelContext) throws -> [NightReminderSetting] {
        var descriptor = FetchDescriptor<NightReminderSetting>(sortBy: [SortDescriptor(\.createdDateTime)])
        // 登録できる本数は maxNightReminderCount までのため、それを超える件数は読み込まない
        descriptor.fetchLimit = maxNightReminderCount
        return try modelContext.fetch(descriptor)
    }
}
