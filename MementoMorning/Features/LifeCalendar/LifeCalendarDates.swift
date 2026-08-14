import Foundation

/// 指定した日が属する週の開始日 (0 時) を返す
private func startOfWeek(date: Date, calendar: Calendar) -> Date {
    // グレゴリオ暦系の Calendar で weekOfYear の dateInterval が nil になることはないため force unwrap する
    calendar.dateInterval(of: .weekOfYear, for: date)!.start
}

/// 人生カレンダー (週単位グリッド) に表示する全ての日 (各日の 0 時) を古い順で返す。要素数は常に 7 の倍数
///
/// 誕生日等の設定はまだ存在しないため、未設定時のデフォルト表示として
/// 「最初の回答が属する週から今日が属する週まで」を表示する。
/// 回答がない・回答歴が浅い場合でも最低 13 週分のグリッドを描画し、空のグリッドとして破綻なく表示できるようにする
func lifeCalendarDays(answeredDates: [Date], today: Date, calendar: Calendar) -> [Date] {
    let todayWeekStart = startOfWeek(date: today, calendar: calendar)
    // 13 週 (= 91 日) は、PROJECT.md の 90 日の節目「問い直し」までの道のりをひと目で見渡せる最小の週数として選んだ
    let minimumWeekStart = calendar.date(byAdding: .weekOfYear, value: -12, to: todayWeekStart)!
    let firstWeekStart = answeredDates.min().map { min(startOfWeek(date: $0, calendar: calendar), minimumWeekStart) } ?? minimumWeekStart
    let endExclusive = calendar.date(byAdding: .day, value: 7, to: todayWeekStart)!

    var days: [Date] = []
    var day = firstWeekStart
    while day < endExclusive {
        days.append(day)
        day = calendar.date(byAdding: .day, value: 1, to: day)!
    }
    return days
}
