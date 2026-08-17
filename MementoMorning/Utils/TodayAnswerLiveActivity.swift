import ActivityKit
import Foundation

/// 「今日の目標」Live Activity の staleDate (翌日 0 時) を返す純粋関数。
/// 今日の回答は日付が変わると意味を失うため、翌日 0 時を過ぎた表示はシステムに stale (更新待ち) として扱わせる。
/// 翌日 0 時の計算に失敗するカレンダーでは staleDate なし (nil) で表示を続ける
func todayAnswerActivityStaleDate(now: Date, calendar: Calendar = .current) -> Date? {
    calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
}

/// 「今日の目標」のロック画面 Live Activity を今日の回答の実状態に合わせる (冪等)。
/// - todayAnswerText が nil (未回答・回答削除・日付跨ぎ): 表示中の Live Activity を終了する
/// - 表示中の Live Activity があれば本文を更新し、無ければ新規に開始する
/// Live Activity はシステムの制約で開始から約 8 時間で自動終了するため「終日残り続ける」は保証できない。
/// バックエンドを持たないアプリのためプッシュ通知での延長は使えず、foreground 復帰のたびに
/// 本関数で再開するベストエフォート方式にする (呼び出し箇所: 回答の成立・編集・文字起こしの反映・foreground 復帰・日付跨ぎ)。
/// 表示の失敗は回答フロー (アラーム停止) を妨げないよう throw しない
@MainActor
func refreshTodayAnswerLiveActivity(todayAnswerText: String?, now: Date = .now) async {
    // 終了済み (ended / dismissed) の残骸は更新できないため、生きているものだけを対象にする
    let activities = Activity<TodayAnswerActivityAttributes>.activities.filter {
        $0.activityState == .active || $0.activityState == .stale
    }
    guard let todayAnswerText else {
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return
    }
    let content = ActivityContent(
        state: TodayAnswerActivityAttributes.ContentState(text: todayAnswerText),
        staleDate: todayAnswerActivityStaleDate(now: now)
    )
    if let activity = activities.first {
        // 「今日の目標」は常に 1 本。二重に開始してしまった残りは畳んでから更新する
        for extraActivity in activities.dropFirst() {
            await extraActivity.end(nil, dismissalPolicy: .immediate)
        }
        await activity.update(content)
    } else {
        // ユーザーが設定でこのアプリの Live Activity を無効にしている間は開始できない (設定変更後の foreground 復帰で再開される)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            _ = try Activity.request(attributes: TodayAnswerActivityAttributes(), content: content)
        } catch {
            print("[TodayAnswerLiveActivity] failed to request: \(error)")
        }
    }
}
