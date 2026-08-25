import Combine
import SwiftUI
import SwiftData

/// MonthCalendarPage が表示する回答の取得条件。
/// 回答済みマークと月送りの下限 (最古の回答月) をこの取得結果から導出する。
/// 履歴系クエリのため fetchLimit を設定する (.claude/rules/swiftdata-guidelines.md)。
/// 上限 731 件は 1 日 1 回答 × 2 年分 (366 日 × 2)。それより古い回答は answeredDate 降順のため取得されない
private var monthCalendarAnswersDescriptor: FetchDescriptor<MorningAnswer> {
    var descriptor = FetchDescriptor<MorningAnswer>(
        sortBy: [SortDescriptor(\MorningAnswer.answeredDate, order: .reverse)]
    )
    descriptor.fetchLimit = 731
    return descriptor
}

/// 月めくりのカレンダー画面 (issue #119)。実際のカレンダーの読み方 (月・日付数字) で「いつ答えたか」を確かめる。
/// 答えた日は温白の粒に墨の数字、今日にだけ夜明け色のリング (アクセントは各画面 1 箇所まで)
struct MonthCalendarPage: View {
    @Environment(\.modelContext) private var modelContext
    @Query(monthCalendarAnswersDescriptor) private var answers: [MorningAnswer]
    /// 表示中の月 (月初の 0 時)
    @State private var displayedMonth = startOfMonth(date: .now, calendar: .current)
    /// 全期間の回答数。クエリは 2 年分に制限しているため、件数は fetchCount で全期間から取得する
    @State private var answeredCount = 0
    /// 日付のマスのタップで選択され、グリッドの下に行表示する回答
    @State private var selectedAnswer: MorningAnswer?
    /// 共有カードを表示する対象の回答。グリッドの下に出た行をタップして選んだ回答
    @State private var shareTargetAnswer: MorningAnswer?
    /// 動画の再生画面 (AnswerVideoPlayerPage) を開く対象の動画 (issue #80)
    @State private var replayTargetVideo: VideoAnswerReplayTarget?
    /// ペイウォールの表示状態。無料枠で隠れている日 (7 日より前) のマスから開く
    @State private var isPaywallPresented = false

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        // 同じ日の回答は 1 件に保たれるが、暦の変わり目で重複しても最初の 1 件で安定させる
        let answersByDay = Dictionary(answers.map { (calendar.startOfDay(for: $0.answeredDate), $0) }, uniquingKeysWith: { first, _ in first })
        // 月送りの範囲は最古の回答の月〜今月 (回答がなければ今月のみ)
        let earliestMonth = answers.last.map { startOfMonth(date: $0.answeredDate, calendar: calendar) } ?? startOfMonth(date: today, calendar: calendar)
        let currentMonth = startOfMonth(date: today, calendar: calendar)
        VStack(spacing: 0) {
            Spacer()
            monthPager(earliestMonth: earliestMonth, currentMonth: currentMonth, calendar: calendar)
            weekdayHeader(calendar: calendar)
                .padding(.top, 30)
            monthGrid(answersByDay: answersByDay, today: today, calendar: calendar)
                .padding(.top, 6)
            if let selectedAnswer {
                AnswerLogRow(
                    answer: selectedAnswer,
                    shareAction: { shareTargetAnswer = selectedAnswer },
                    replayVideoAction: { replayTargetVideo = VideoAnswerReplayTarget(videoAssetIdentifier: $0) }
                )
                // AnswerLogRow が本文の上に 19 の余白を持つため、グリッドとの間はヘアラインと同じリズム (34) になるよう 15 を足す
                .padding(.top, 15)
            }
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
                Text(verbatim: "\(answeredCount)")
                    .font(.system(size: 30, weight: .ultraLight))
                    .foregroundStyle(Color.warmWhite)
            }
            .padding(.top, 26)
            Spacer()
        }
        .padding(.horizontal, 34)
        .background(Color.ink.ignoresSafeArea())
        // 別の月に切り替えたら、前の月の日付で選んだ行を残さない
        .onChange(of: displayedMonth) { _, _ in
            selectedAnswer = nil
        }
        .onAppear {
            answeredCount = (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) ?? 0
        }
        // この画面を開いたまま回答が保存されても onAppear は再発火しないため、保存通知で件数を再計算する (HomeContent と同じパターン)
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            answeredCount = (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) ?? 0
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                // ja: カレンダー
                Text("Calendar")
                    .font(.system(size: 15, weight: .medium))
                    .tracking(2.1)
                    .foregroundStyle(Color.warmWhite)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareTargetAnswer) { answer in
            AnswerShareCardPage(answer: answer)
        }
        .sheet(item: $replayTargetVideo) { target in
            AnswerVideoPlayerPage(videoAssetIdentifier: target.videoAssetIdentifier)
        }
        .sheet(isPresented: $isPaywallPresented) {
            PaywallPage()
        }
    }

    /// 月送り (前月・翌月) と表示中の月名
    private func monthPager(earliestMonth: Date, currentMonth: Date, calendar: Calendar) -> some View {
        HStack(spacing: 18) {
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)!
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color.warmWhite.opacity(displayedMonth > earliestMonth ? 0.3 : 0.12))
                    .frame(width: 44, height: 44)
            }
            .disabled(displayedMonth <= earliestMonth)
            // ja: 前の月
            .accessibilityLabel(String(localized: "Previous month"))
            // 見出しはグリッドと同じ暦 (Calendar.current。和暦・イスラム暦等の設定を含む) で整形し、
            // 言語だけをアプリの表示言語に合わせる。暦を渡さないと既定のグレゴリオ暦で整形され、日付の並びと見出しがずれる
            Text(verbatim: displayedMonth.formatted(Date.FormatStyle(locale: calendarDisplayLocale, calendar: calendar).year().month(.wide)))
                .font(.system(size: 20, weight: .light))
                .tracking(1.6)
                .foregroundStyle(Color.warmWhite)
                .frame(minWidth: 170)
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color.warmWhite.opacity(displayedMonth < currentMonth ? 0.3 : 0.12))
                    .frame(width: 44, height: 44)
            }
            .disabled(displayedMonth >= currentMonth)
            // ja: 翌月
            .accessibilityLabel(String(localized: "Next month"))
        }
    }

    /// 曜日ヘッダー (グリッドの列と同じ並び)
    private func weekdayHeader(calendar: Calendar) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
            let weekdaySymbols = calendarWeekdaySymbols(calendar: calendar)
            // 曜日記号は言語によって重複する (英語の S/T 等) ため列番号を id にする
            ForEach(0..<7, id: \.self) { weekdayColumnIndex in
                Text(verbatim: weekdaySymbols[weekdayColumnIndex])
                    .font(.system(size: 9))
                    .tracking(1.8)
                    .foregroundStyle(Color.warmWhite.opacity(0.35))
                    .frame(height: 24)
            }
        }
        .accessibilityHidden(true)
    }

    /// 表示中の月の日付グリッド。answersByDay は日付 (現在の暦での startOfDay) から回答を引く辞書で、
    /// 回答済みマークの表示もタップでグリッドの下に出す回答もこの同じ辞書から取る
    private func monthGrid(answersByDay: [Date: MorningAnswer], today: Date, calendar: Calendar) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
            let cells = monthCalendarCells(month: displayedMonth, calendar: calendar)
            // マスの並びは月が同じなら不変のため位置を id にする
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                Group {
                    if let day {
                        monthGridDayCell(day: day, answer: answersByDay[day], today: today, calendar: calendar)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 48)
            }
        }
    }

    /// 日付 1 マスぶんの表示。答えた日は温白の粒に墨の数字、それ以外は数字のみ (未来は弱く)。
    /// 答えた日はタップでその日の回答をグリッドの下にジャーナルと同じ行で表示し、無料枠で隠れている日 (7 日より前) はペイウォールを開く (issue #130)。
    /// answer は monthGrid から渡されるその日の回答で、回答済みの表示もタップで選ぶ回答も同じ値を基準にする
    private func monthGridDayCell(day: Date, answer: MorningAnswer?, today: Date, calendar: Calendar) -> some View {
        let isAnswered = answer != nil
        return Button {
            // 未回答の日は disabled のためここには来ない
            guard let answer else {
                return
            }
            if AnswerLogVisibility.isVisible(answeredDate: answer.answeredDate, isPremium: PremiumEntitlement.isPremium) {
                selectedAnswer = answer
            } else {
                isPaywallPresented = true
            }
        } label: {
            ZStack {
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
                Text(verbatim: "\(calendar.component(.day, from: day))")
                    .font(.system(size: 11, weight: isAnswered ? .medium : .light))
                    .foregroundStyle(isAnswered ? Color.ink : Color.warmWhite.opacity(day <= today ? 0.45 : 0.18))
            }
            // plain スタイルの Button は円と数字の描画領域しかタップに反応しないため、
            // ラベルをマスの大きさ (高さは monthGrid のマスと同じ 48) まで広げてからヒット領域にする
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 開く回答があるのは答えた日だけ
        .disabled(!isAnswered)
        .accessibilityLabel(
            // Text の + 連結は iOS 26.0 で deprecated のため String を組み立ててから渡す。
            // 日付は見出しと同じくアプリの表示言語とグリッドの暦で整形する (読み上げだけ端末言語・既定の暦にならないようにする)
            Text(verbatim: day.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: calendarDisplayLocale, calendar: calendar)) + ", "
                + (isAnswered
                    // ja: 回答済み
                    ? String(localized: "Answered")
                    // ja: 未回答
                    : String(localized: "Not answered")))
        )
    }
}

struct MonthCalendarPage_Previews: PreviewProvider {
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
            MonthCalendarPage()
        }
        .modelContainer(container)
    }
}
