import Foundation

/// カレンダー表示 (月ラベル・曜日記号) の言語。Locale.current は端末の言語設定そのものを返し、
/// アプリが対応しない言語にもなり得るため、LegalLinks.swift と同じく Bundle.main.preferredLocalizations で
/// アプリの実際の表示言語に合わせる。フォールバックの "en" はアプリの基本言語 (localization-guidelines.md) に合わせている
var calendarDisplayLocale: Locale {
    Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
}

/// Calendar.firstWeekday を起点に並べ替えた曜日記号 (日月火... / S M T...)。
/// monthCalendarCells の列の並びも同じ firstWeekday に従うため、ヘッダーの列とグリッドの列が一致する
func calendarWeekdaySymbols(calendar: Calendar) -> [String] {
    // 記号の言語だけをアプリの表示言語に合わせ、週の起点 (firstWeekday) は引数の calendar のものを維持する
    var localizedCalendar = calendar
    localizedCalendar.locale = calendarDisplayLocale
    return (0..<7).map { localizedCalendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + $0) % 7] }
}

/// date が属する月の月初 (1 日の 0 時) を返す
func startOfMonth(date: Date, calendar: Calendar) -> Date {
    // グレゴリオ暦系の Calendar で month の dateInterval が nil になることはないため force unwrap する
    calendar.dateInterval(of: .month, for: date)!.start
}

/// 月カレンダー (7 列グリッド) に表示するマスを先頭 (左上) から順に返す。要素数は常に 7 の倍数。
/// その月に属さない先頭・末尾の空きマスは nil
func monthCalendarCells(month: Date, calendar: Calendar) -> [Date?] {
    let monthStart = startOfMonth(date: month, calendar: calendar)
    // グレゴリオ暦系の Calendar で month 内の day の range が nil になることはないため force unwrap する
    let dayCount = calendar.range(of: .day, in: .month, for: monthStart)!.count
    // 月初が入る曜日列 (firstWeekday 起点の 0..6)。その手前を空きマスで埋める
    let leadingEmptyCount = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
    var cells: [Date?] = Array(repeating: nil, count: leadingEmptyCount)
    for dayOffset in 0..<dayCount {
        cells.append(calendar.date(byAdding: .day, value: dayOffset, to: monthStart)!)
    }
    while cells.count % 7 != 0 {
        cells.append(nil)
    }
    return cells
}
