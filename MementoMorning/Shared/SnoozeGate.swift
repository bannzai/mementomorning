import Foundation
import SwiftData

/// 無料枠で追撃アラーム (スヌーズ) を再登録できる上限回数。
/// 根拠: documents/PROJECT.md の課金設計「無料: スヌーズ 2 回まで / プレミアム: 無限追撃アラーム」
let freeTierSnoozeLimit = 2

/// スヌーズ回数として選べる有限の回数 (issue #73)。この範囲に加えて「無制限」(nil) を選べる。
/// 無料は freeTierSnoozeLimit までしか選べず、それ以上と無制限はプレミアム
let snoozeLimitChoices = 1...10

/// スヌーズ (追撃) の間隔として選べる分数 (issue #135)。課金線は回数側 (snoozeLimit) にあり、間隔は無料で選べる
let snoozeIntervalChoices = 1...10

/// スヌーズ間隔の既定の分数。
/// 根拠: 設定導入前の固定値 (2 分。二度寝に落ち切る前に追撃しつつ、アラーム発火の確認を 1〜2 分後で回す
/// 検証運用にも合う値) を踏襲し、既存ユーザーの挙動を変えない
let defaultSnoozeIntervalMinutes = 2

/// 設定値 (AlarmSetting.snoozeIntervalMinutes) から実効のスヌーズ間隔 (分) を返す。
/// nil (未設定・設定導入前の既存レコード) と選択肢の範囲外は既定値に倒す。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func effectiveSnoozeIntervalMinutes(snoozeIntervalMinutes: Int?) -> Int {
    guard let snoozeIntervalMinutes, snoozeIntervalChoices.contains(snoozeIntervalMinutes) else {
        return defaultSnoozeIntervalMinutes
    }
    return snoozeIntervalMinutes
}

/// 設定値 (AlarmSetting.snoozeLimit) が現在の課金状態で選択可能か。
/// 無料は freeTierSnoozeLimit 以下の回数だけ選べ、それを超える回数と無制限 (nil) はプレミアムでのみ選べる。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func isSnoozeLimitSelectable(snoozeLimit: Int?, isPremium: Bool) -> Bool {
    if isPremium { return true }
    guard let snoozeLimit else { return false }
    return snoozeLimit <= freeTierSnoozeLimit
}

/// 設定値と課金状態から、実際に追撃を打ち切る回数を返す (nil = 無制限)。
/// 選択不能な設定値 (未設定の nil や、プレミアム失効後に残った回数) は無料枠 freeTierSnoozeLimit に丸める。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func effectiveSnoozeLimit(snoozeLimit: Int?, isPremium: Bool) -> Int? {
    if isSnoozeLimitSelectable(snoozeLimit: snoozeLimit, isPremium: isPremium) {
        return snoozeLimit
    }
    return freeTierSnoozeLimit
}

/// アラーム停止時に追撃アラームを再登録すべきか。
/// 連続追撃回数が effectiveSnoozeLimit に達したら打ち切り、無制限なら常に追撃する。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func shouldChase(chaseCount: Int, snoozeLimit: Int?, isPremium: Bool) -> Bool {
    guard let limit = effectiveSnoozeLimit(snoozeLimit: snoozeLimit, isPremium: isPremium) else { return true }
    return chaseCount < limit
}

/// 今日 (0 時基準) の回答が既に記録されているか。
/// 追撃カウント (stopIntentChaseCount) のリセット条件に使う: openAppWhenRun による foreground 復帰でも
/// scenePhase の .active ハンドラは走るため、無条件にリセットすると未回答のまま停止を繰り返すたびに
/// カウントが 0 に戻り、スヌーズ上限 (effectiveSnoozeLimit) に到達しない
@MainActor
func hasTodayAnswer(modelContext: ModelContext, calendar: Calendar = .current, now: Date = .now) -> Bool {
    fetchMorningAnswer(answeredDate: now, modelContext: modelContext, calendar: calendar) != nil
}
