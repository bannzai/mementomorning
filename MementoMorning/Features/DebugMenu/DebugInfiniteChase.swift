import Foundation

#if DEBUG
extension String {
    /// 無限アラーム検証用のテストアラームの UUID を保存する UserDefaults キー (DEBUG 限定。DebugMenuPage から登録する)。
    /// 再登録時に前回のテストアラームをキャンセルし、テストアラームを常に 1 本に保つ (冪等) ために使う
    static let debugChaseTestAlarmID = "debugChaseTestAlarmID"
}

/// 検証用テストアラームが発火するまでの秒数。
/// アラーム発火の確認は「1〜2 分後のアラーム」で行う運用 (CLAUDE.md「検証方法」) に合わせて 1 分にする
let debugChaseTestAlarmInterval: TimeInterval = 60

/// 無限追撃アラーム (プレミアムの「答えるまで止まらない」) の検証を妨げる状態の一覧を返す。空なら検証を始められる。
/// 追撃の成立条件が複数箇所 (StopAlarmIntent の未回答判定・Rescheduler の保護判定・SnoozeGate の上限判定) に
/// 分かれていて揃え漏れに気づきにくいため、DebugMenuPage が前提の充足を一覧表示するのに使う。
/// 文言は開発者メニュー専用のためローカライズしない。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
/// - Parameters:
///   - alarmSettingIsEnabled: 保存済みアラーム設定の有効フラグ。nil は設定レコードなし
///   - snoozeLimit: 保存済みアラーム設定のスヌーズ上限 (nil = 無制限)
///   - isPremium: 現在のプレミアム判定 (PremiumEntitlement.isPremium)
///   - hasTodayAnswer: 今日の回答 (MorningAnswer) が成立しているか
func debugInfiniteChaseBlockers(
    alarmSettingIsEnabled: Bool?,
    snoozeLimit: Int?,
    isPremium: Bool,
    hasTodayAnswer: Bool
) -> [String] {
    var blockers: [String] = []
    if alarmSettingIsEnabled != true {
        blockers.append("アラーム設定が OFF (foreground 復帰時の reschedule が追撃をキャンセルする)")
    }
    if effectiveSnoozeLimit(snoozeLimit: snoozeLimit, isPremium: isPremium) != nil {
        blockers.append("実効スヌーズ上限が有限 (プレミアム強制 + スヌーズ無制限で無限になる)")
    }
    if hasTodayAnswer {
        blockers.append("今日の回答が成立済み (追撃は登録されない)")
    }
    return blockers
}
#endif
