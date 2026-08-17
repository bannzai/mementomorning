import ActivityKit
import Foundation

/// Live Activity の ContentState 全体 (JSON エンコード後) のバイト数の上限。
/// ActivityKit には属性 + ContentState の合計 4KB のサイズ上限があり、超えると開始 (request)・更新が失敗する。
/// 属性 (TodayAnswerActivityAttributes はプロパティなし) の取り分を差し引いても 4KB に収まるよう 2KB とする (表示は最大 3 行のため表示にも足りる)
let todayAnswerActivityContentStateByteLimit = 2048

/// text を格納した ContentState の JSON エンコード後のバイト数。エンコードに失敗した場合は上限超過として扱う (fail-closed)
private func todayAnswerActivityEncodedByteCount(text: String) -> Int {
    (try? JSONEncoder().encode(TodayAnswerActivityAttributes.ContentState(text: text)).count) ?? .max
}

/// Live Activity に表示する本文を返す純粋関数。長さ無制限の回答本文をサイズ上限内に切り詰める (表示専用。永続化される回答本文は変えない)。
/// 文字数や生の UTF-8 バイト数ではなく、実際にエンコードされる ContentState のバイト数で判定する
/// (複数 scalar の絵文字は文字数を、引用符・改行等の JSON エスケープは生バイト数を、それぞれエンコード後サイズより小さく見せるため)。
/// 切り詰めは書記素クラスタ (Character) の境界で行い、絵文字や結合文字が途中で壊れないようにする
func todayAnswerActivityDisplayText(text: String) -> String {
    // JSON エスケープでバイト数が減ることはないため、まず生の UTF-8 バイト数で上限まで切り詰めて、エンコード判定の回数を抑える
    var displayText = ""
    var byteCount = 0
    for character in text {
        let characterByteCount = String(character).utf8.count
        if byteCount + characterByteCount > todayAnswerActivityContentStateByteLimit { break }
        displayText.append(character)
        byteCount += characterByteCount
    }
    while !displayText.isEmpty, todayAnswerActivityEncodedByteCount(text: displayText) > todayAnswerActivityContentStateByteLimit {
        displayText.removeLast()
    }
    return displayText
}

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
    let activities = Activity<TodayAnswerActivityAttributes>.activities
    // 終了済み (ended / dismissed) の残骸は更新できないため、更新対象は生きているものに絞る。
    // 終了系の操作は残骸にも行う (システムの約 8 時間での自動終了後もロック画面に最大 4 時間残り得るため、
    // 残骸を放置すると再開時に古い表示と並んでしまう。終了済みへの end は無害)
    let liveActivities = activities.filter {
        $0.activityState == .active || $0.activityState == .stale
    }
    guard let todayAnswerText else {
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return
    }
    let content = ActivityContent(
        state: TodayAnswerActivityAttributes.ContentState(text: todayAnswerActivityDisplayText(text: todayAnswerText)),
        staleDate: todayAnswerActivityStaleDate(now: now)
    )
    if let activity = liveActivities.first {
        // 「今日の目標」は常に 1 本。二重に開始してしまった残り・終了済みの残骸は畳んでから更新する
        for extraActivity in activities where extraActivity.id != activity.id {
            await extraActivity.end(nil, dismissalPolicy: .immediate)
        }
        await activity.update(content)
    } else {
        // 自動終了後の残骸をロック画面から下ろしてから開始し直す
        for leftoverActivity in activities {
            await leftoverActivity.end(nil, dismissalPolicy: .immediate)
        }
        // ユーザーが設定でこのアプリの Live Activity を無効にしている間は開始できない (設定変更後の foreground 復帰で再開される)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            _ = try Activity.request(attributes: TodayAnswerActivityAttributes(), content: content)
        } catch {
            print("[TodayAnswerLiveActivity] failed to request: \(error)")
        }
    }
}
