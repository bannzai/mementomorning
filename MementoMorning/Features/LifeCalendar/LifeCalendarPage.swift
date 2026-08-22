import SwiftUI
import SwiftData

/// LifeCalendarPage が表示する回答の取得条件。
/// グリッドの表示範囲 (最古の回答週) と回答済みマークの両方をこの取得結果から導出する。
/// 履歴系クエリのため fetchLimit を設定する (.claude/rules/swiftdata-guidelines.md)。
/// 上限 731 件は 1 日 1 回答 × 2 年分 (366 日 × 2)。それより古い回答は answeredDate 降順のため取得されず、
/// グリッドの表示範囲も取得できた最古の回答週までに収まる
private var lifeCalendarAnswersDescriptor: FetchDescriptor<MorningAnswer> {
    var descriptor = FetchDescriptor<MorningAnswer>(
        sortBy: [SortDescriptor(\MorningAnswer.answeredDate, order: .reverse)]
    )
    descriptor.fetchLimit = 731
    return descriptor
}

/// グリッドの粒の直径。デザイン handoff 1g の 13pt 粒に合わせる
private let lifeCalendarDotSize: CGFloat = 13
/// 粒どうし・行どうしの間隔。デザイン handoff 1g の 11pt 間隔に合わせる
private let lifeCalendarDotSpacing: CGFloat = 11
/// 月ラベル列の幅。年併記時の最長表示 (例: 2026年12月) が 9pt フォントで収まる幅として選んだ。
/// グリッドの中央寄せを保つため、行の右端にも同じ幅の余白を置いて対で使う
private let lifeCalendarMonthLabelWidth: CGFloat = 56

/// Calendar.firstWeekday を起点に並べ替えた曜日記号 (日月火... / S M T...)。
/// lifeCalendarDays の週の区切りも同じ firstWeekday に従うため、ヘッダーの列とグリッドの列が一致する
private func lifeCalendarWeekdaySymbols(calendar: Calendar) -> [String] {
    (0..<7).map { calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + $0) % 7] }
}

/// 週の行頭に表示する月ラベルの文字列。
/// 年の変わり目 (1 月) と最初の行では年も併記し、複数年の履歴でもどの年の粒か辿れるようにする
private func lifeCalendarMonthLabel(anchorDay: Date, isFirstWeek: Bool, calendar: Calendar) -> String {
    if isFirstWeek || calendar.component(.month, from: anchorDay) == 1 {
        return anchorDay.formatted(.dateTime.month(.abbreviated).year())
    }
    return anchorDay.formatted(.dateTime.month(.abbreviated))
}

/// 答えた朝が一粒ずつ墨のように埋まっていく人生カレンダー (週単位グリッド)。1 行が 1 週間、1 マスが 1 日。
/// 月ラベルと曜日ヘッダーで粒の並びに時間軸の意味を添える (issue #110)。
/// デザイン handoff 1g / プロトタイプ calendar 準拠。
/// streak 修復は作らない (documents/PROJECT.md の課金設計参照)
struct LifeCalendarPage: View {
    @Environment(\.modelContext) private var modelContext
    @Query(lifeCalendarAnswersDescriptor) private var answers: [MorningAnswer]
    /// 全期間の回答数 (答えた日数 N)。グリッド用クエリは 2 年分に制限しているため、件数は fetchCount で全期間から取得する
    @State private var answeredCount = 0

    var body: some View {
        let calendar = Calendar.current
        let answeredDays = Set(answers.map { calendar.startOfDay(for: $0.answeredDate) })
        let days = lifeCalendarDays(answeredDates: answers.map(\.answeredDate), today: .now, calendar: calendar)
        let today = calendar.startOfDay(for: .now)
        VStack(spacing: 0) {
            // ja: 1行が1週間。答えた日が点として残る
            Text("Each row is a week. Answered mornings remain as dots.")
                .font(.system(size: 11))
                .tracking(0.66)
                .foregroundStyle(Color.warmWhite.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 40)
            ScrollViewReader { proxy in
                GeometryReader { geometry in
                    ScrollView {
                        let weeks = lifeCalendarWeeks(days: days)
                        // 曜日ヘッダーは pinned section header にする。履歴が浅くグリッドが中央寄せの間はグリッド直上に付き、
                        // 履歴が長くスクロールする時は上部に固定されて列の意味を示し続ける
                        LazyVStack(spacing: lifeCalendarDotSpacing, pinnedViews: [.sectionHeaders]) {
                            Section {
                                // 週の中身は範囲が同じなら不変のため行番号を id にする
                                ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                                    HStack(spacing: lifeCalendarDotSpacing) {
                                        Group {
                                            if let anchorDay = lifeCalendarMonthAnchorDay(week: week, isFirstWeek: weekIndex == 0, calendar: calendar) {
                                                Text(verbatim: lifeCalendarMonthLabel(anchorDay: anchorDay, isFirstWeek: weekIndex == 0, calendar: calendar))
                                            } else {
                                                Text(verbatim: "")
                                            }
                                        }
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.warmWhite.opacity(0.4))
                                        .frame(width: lifeCalendarMonthLabelWidth, alignment: .trailing)
                                        ForEach(week, id: \.self) { day in
                                            Circle()
                                                .fill(answeredDays.contains(day) ? Color.warmWhite : Color.warmWhite.opacity(0.09))
                                                .frame(width: lifeCalendarDotSize, height: lifeCalendarDotSize)
                                                .overlay {
                                                    // 今日の粒だけに夜明け色のリングを添える (アクセントは各画面 1 箇所まで)
                                                    if day == today {
                                                        Circle()
                                                            .stroke(Color.dawn.opacity(0.35), lineWidth: 3)
                                                            .frame(width: 20, height: 20)
                                                    }
                                                }
                                                .accessibilityLabel(
                                                    // Text の + 連結は iOS 26.0 で deprecated のため String を組み立ててから渡す
                                                    Text(verbatim: day.formatted(date: .complete, time: .omitted) + ", "
                                                        + (answeredDays.contains(day)
                                                            // ja: 回答済み
                                                            ? String(localized: "Answered")
                                                            // ja: 未回答
                                                            : String(localized: "Not answered")))
                                                )
                                                .id(day)
                                        }
                                        // 月ラベル列と対の余白。グリッド (粒の並び) を画面中央に保つ
                                        Color.clear.frame(width: lifeCalendarMonthLabelWidth, height: 1)
                                    }
                                }
                            } header: {
                                // 曜日ヘッダー。グリッドの列 (firstWeekday 起点) と同じ並びで各列の意味を示す。
                                // 固定時に下の粒が透けないよう背景を敷く
                                HStack(spacing: lifeCalendarDotSpacing) {
                                    Color.clear.frame(width: lifeCalendarMonthLabelWidth, height: 1)
                                    let weekdaySymbols = lifeCalendarWeekdaySymbols(calendar: calendar)
                                    // 曜日記号は言語によって重複する (英語の S/T 等) ため列番号を id にする
                                    ForEach(0..<7, id: \.self) { weekdayColumnIndex in
                                        Text(verbatim: weekdaySymbols[weekdayColumnIndex])
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color.warmWhite.opacity(0.35))
                                            .frame(width: lifeCalendarDotSize)
                                    }
                                    Color.clear.frame(width: lifeCalendarMonthLabelWidth, height: 1)
                                }
                                .padding(.vertical, 4)
                                .background(Color.ink)
                                .accessibilityHidden(true)
                            }
                        }
                        .padding(.vertical, 28)
                        // 履歴が浅くグリッドがスクロール領域より小さい時は上に寄せず、キャプションとフッターの間の中央に置く (issue #72)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
                    // 履歴が画面を超えても今日の週 (末尾) が初期表示されるようにする。
                    // defaultScrollAnchor(.bottom) はコンテンツが画面より小さい時にグリッドが下寄せになり
                    // コピーとの間に大きな空白ができるため、初回スクロールだけを行う
                    .onAppear {
                        if let lastDay = days.last {
                            proxy.scrollTo(lastDay, anchor: .bottom)
                        }
                    }
                }
            }
            VStack(spacing: 6) {
                // 記録日数はこの画面の主情報のため、キャプションより一段強い書体で見落とされないようにする (issue #110)
                // ja: 答えた日数 %lld日
                Text("\(answeredCount) mornings answered")
                    .font(.system(size: 15, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(Color.warmWhite.opacity(0.85))
                // ja: 点はいつかつながる
                Text("The dots will connect.")
                    .font(.system(size: 11))
                    .tracking(0.88)
                    .foregroundStyle(Color.warmWhite.opacity(0.32))
            }
            .padding(.bottom, 24)
        }
        .background(Color.ink.ignoresSafeArea())
        .onAppear {
            answeredCount = (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) ?? 0
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                // ja: 人生カレンダー
                Text("Life Calendar")
                    .font(.system(size: 15, weight: .medium))
                    .tracking(2.1)
                    .foregroundStyle(Color.warmWhite)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LifeCalendarPage_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        let modelContext = ModelContext(container)
        // 今日・3 日前・10 日前に回答した状態のサンプルデータ (回答本文はユーザーの自由入力値のためハードコード)
        let _ = {
            // Preview の body は複数回評価されるため、共有 in-memory コンテナへの重複挿入を防いで冪等にする
            guard (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) == 0 else { return }
            let calendar = Calendar.current
            modelContext.insert(MorningAnswer(answeredDate: calendar.startOfDay(for: .now), text: "家族と過ごす"))
            modelContext.insert(MorningAnswer(answeredDate: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -3, to: .now)!), text: "海を見に行く"))
            modelContext.insert(MorningAnswer(answeredDate: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -10, to: .now)!), text: "手紙を書く"))
            try! modelContext.save()
        }()
        NavigationStack {
            LifeCalendarPage()
        }
        .modelContainer(container)
    }
}
