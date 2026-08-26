import SwiftUI

/// 月めくりカレンダー画面 (MonthCalendarPage) のモック。
/// 答えた日は温白の粒に墨の数字、今日にだけ夜明け色のリング (アクセントは各画面 1 箇所まで) を本番のトークンどおりに再現する。
/// スクリーンショットは毎回同じ絵にするため、暦の計算をせず 2026 年 8 月 (1 日が土曜・31 日まで) の固定値で静止描画する
struct MockCalendarScreen: View {
    /// 今日の日付。26 日 (水曜) を「今日」とし、1〜26 日を回答済みにする
    private let today = 26
    /// 月初 (1 日) が入る曜日列の手前の空きマス数。2026 年 8 月 1 日は土曜のため日曜起点で 6
    private let leadingEmptyCount = 6
    /// 月の日数。2026 年 8 月は 31 日まで
    private let dayCount = 31

    var body: some View {
        VStack(spacing: 0) {
            // ja: カレンダー
            Text("Calendar")
                .font(.system(size: 15, weight: .medium))
                .tracking(2.1)
                .foregroundStyle(Color.warmWhite)
                .padding(.top, 70)

            Spacer()

            monthPager
            weekdayHeader
                .padding(.top, 30)
            monthGrid
                .padding(.top, 6)
            Rectangle()
                .fill(Color.hairline)
                .frame(height: 1)
                .padding(.horizontal, 40)
                .padding(.top, 34)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                // ja: 答えた朝
                Text("Mornings answered")
                    .font(.system(size: 11))
                    .tracking(2.2)
                    .foregroundStyle(Color.warmWhite.opacity(0.4))
                // 今月の 26 日分に前月の回答を足した全期間の件数。粒画面から引き継いだ「答えた朝 32」と数を一致させる
                Text(verbatim: "32")
                    .font(.system(size: 30, weight: .ultraLight))
                    .foregroundStyle(Color.warmWhite)
            }
            .padding(.top, 26)

            Spacer()
        }
        .padding(.horizontal, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ink)
    }

    /// 月送り (前月・翌月) と表示中の月名。前月には回答があるため戻れる (30%)、表示中が今月のため翌月は進めない (12%)
    private var monthPager: some View {
        HStack(spacing: 18) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Color.warmWhite.opacity(0.3))
                .frame(width: 44, height: 44)
            // ja: 2026年8月
            Text("August 2026")
                .font(.system(size: 20, weight: .light))
                .tracking(1.6)
                .foregroundStyle(Color.warmWhite)
                .frame(minWidth: 170)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Color.warmWhite.opacity(0.12))
                .frame(width: 44, height: 44)
        }
    }

    /// 撮影言語に合わせた曜日記号 (日曜起点)。
    /// 本番 (calendarDisplayLocale) と同じくアプリの表示言語で整形し、暦は日付の固定値と揃うグレゴリオ暦にする
    private var weekdaySymbols: [String] {
        var localizedCalendar = Calendar(identifier: .gregorian)
        localizedCalendar.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        return localizedCalendar.veryShortStandaloneWeekdaySymbols
    }

    /// 曜日ヘッダー (グリッドの列と同じ日曜起点の並び)
    private var weekdayHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
            // 曜日記号は言語によって重複する (英語の S/T 等) ため列番号を id にする
            ForEach(0..<7, id: \.self) { weekdayColumnIndex in
                Text(verbatim: weekdaySymbols[weekdayColumnIndex])
                    .font(.system(size: 9))
                    .tracking(1.8)
                    .foregroundStyle(Color.warmWhite.opacity(0.35))
                    .frame(height: 24)
            }
        }
    }

    /// 8 月の日付グリッド (7 列 × 6 行)。月に属さない先頭・末尾の空きマスは何も描かない
    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
            let cellCount = ((leadingEmptyCount + dayCount + 6) / 7) * 7
            // マスの並びは不変のため位置を id にする
            ForEach(0..<cellCount, id: \.self) { cellIndex in
                Group {
                    let day = cellIndex - leadingEmptyCount + 1
                    if 1 <= day && day <= dayCount {
                        monthGridDayCell(day: day)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 48)
            }
        }
    }

    /// 日付 1 マスぶんの表示。答えた日 (1〜26 日) は温白の粒に墨の数字、未来 (27 日以降) は数字のみ弱く
    private func monthGridDayCell(day: Int) -> some View {
        let isAnswered = day <= today
        return ZStack {
            if isAnswered {
                Circle()
                    .fill(Color.warmWhite)
                    .frame(width: 32, height: 32)
            }
            // 今日にだけ夜明け色のリングを添える (アクセントは各画面 1 箇所まで)
            if day == today {
                Circle()
                    .stroke(Color.dawn.opacity(0.35), lineWidth: 3)
                    .frame(width: 38, height: 38)
            }
            Text(verbatim: "\(day)")
                .font(.system(size: 11, weight: isAnswered ? .medium : .light))
                .foregroundStyle(isAnswered ? Color.ink : Color.warmWhite.opacity(0.18))
        }
        .frame(maxWidth: .infinity)
    }
}
