import Foundation
import WidgetKit

/// ホーム画面ウィジェット「今日の答え」の WidgetKit kind。
/// ウィジェット定義とアプリ側のリロード要求で同じ値を使うため、両ターゲットに含めるここで一元定義する
let todayAnswerWidgetKind = "TodayAnswerWidget"

/// ホーム画面ウィジェットのタイムラインを作り直す日時 (次の 0 時)。
/// 「今日の回答」の表示は日付が変わると古くなるため、日付の境界で必ずエントリを更新する
func homeWidgetReloadDate(now: Date, calendar: Calendar) -> Date {
    calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
}

/// ホーム画面ウィジェットへ今日の回答の変化を即時反映する。回答本文が変わる保存の成功後に呼ぶ。
/// リロード要求だけで結果を持たないため冪等 (何度呼んでも表示は最新の保存内容になる)
func reloadHomeWidgetTimelines() {
    WidgetCenter.shared.reloadTimelines(ofKind: todayAnswerWidgetKind)
}
