import Foundation

/// 無料枠で追撃アラーム (スヌーズ) を再登録できる上限回数。
/// 根拠: documents/PROJECT.md の課金設計「無料: スヌーズ 2 回まで / プレミアム: 無限追撃アラーム」
let freeTierSnoozeLimit = 2

/// アラーム停止時に追撃アラームを再登録すべきか。
/// プレミアムは常に追撃する (無限追撃)。無料は連続追撃回数が freeTierSnoozeLimit に達したら打ち切る。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func shouldChase(chaseCount: Int, isPremium: Bool) -> Bool {
    isPremium || chaseCount < freeTierSnoozeLimit
}
