import Foundation
import SwiftData

/// 無料枠で追撃アラーム (スヌーズ) を再登録できる上限回数。
/// 根拠: documents/PROJECT.md の課金設計「無料: スヌーズ 2 回まで / プレミアム: 無限追撃アラーム」
let freeTierSnoozeLimit = 2

/// アラーム停止時に追撃アラームを再登録すべきか。
/// プレミアムは常に追撃する (無限追撃)。無料は連続追撃回数が freeTierSnoozeLimit に達したら打ち切る。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func shouldChase(chaseCount: Int, isPremium: Bool) -> Bool {
    isPremium || chaseCount < freeTierSnoozeLimit
}

/// 今日 (0 時基準) の回答が既に記録されているか。
/// 追撃カウント (stopIntentChaseCount) のリセット条件に使う: openAppWhenRun による foreground 復帰でも
/// scenePhase の .active ハンドラは走るため、無条件にリセットすると未回答のまま停止を繰り返すたびに
/// カウントが 0 に戻り、無料枠のスヌーズ上限 (freeTierSnoozeLimit) に到達しない
@MainActor
func hasTodayAnswer(modelContext: ModelContext, calendar: Calendar = .current, now: Date = .now) -> Bool {
    let today = calendar.startOfDay(for: now)
    var descriptor = FetchDescriptor<MorningAnswer>(predicate: #Predicate { $0.answeredDate == today })
    descriptor.fetchLimit = 1
    return ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
}
