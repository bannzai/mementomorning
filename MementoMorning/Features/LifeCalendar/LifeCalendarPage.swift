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

/// 答えた朝が一粒ずつ墨のように埋まっていく人生カレンダー (週単位グリッド)。1 行が 1 週間、1 マスが 1 日。
/// デザイン handoff 1g / プロトタイプ calendar 準拠。
/// streak 修復は作らない (documents/PROJECT.md の課金設計参照)
struct LifeCalendarPage: View {
    @Environment(\.modelContext) private var modelContext
    @Query(lifeCalendarAnswersDescriptor) private var answers: [MorningAnswer]
    /// 全期間の回答数 (答えた朝 N)。グリッド用クエリは 2 年分に制限しているため、件数は fetchCount で全期間から取得する
    @State private var answeredCount = 0

    var body: some View {
        let calendar = Calendar.current
        let answeredDays = Set(answers.map { calendar.startOfDay(for: $0.answeredDate) })
        let days = lifeCalendarDays(answeredDates: answers.map(\.answeredDate), today: .now, calendar: calendar)
        let today = calendar.startOfDay(for: .now)
        VStack(spacing: 0) {
            // ja: 1行が一週間。答えた朝が、点として残る。
            Text("Each row is a week. Answered mornings remain as dots.")
                .font(.system(size: 11))
                .tracking(0.66)
                .foregroundStyle(Color.warmWhite.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 40)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(13), spacing: 11), count: 7), spacing: 11) {
                        ForEach(days, id: \.self) { day in
                            Circle()
                                .fill(answeredDays.contains(day) ? Color.warmWhite : Color.warmWhite.opacity(0.09))
                                .frame(width: 13, height: 13)
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
                    }
                    .padding(.vertical, 28)
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
            VStack(spacing: 6) {
                // ja: 答えた朝 %lld
                Text("\(answeredCount) mornings answered")
                    .font(.system(size: 12))
                    .tracking(1.2)
                    .foregroundStyle(Color.warmWhite.opacity(0.55))
                // ja: 点は、いつかつながる。
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
                VStack(spacing: 3) {
                    // ja: 人生カレンダー
                    Text("Life Calendar")
                        .font(.system(size: 15, weight: .medium))
                        .tracking(2.1)
                        .foregroundStyle(Color.warmWhite)
                    Text(verbatim: "LIFE IN WEEKS")
                        .font(.system(size: 9))
                        .tracking(2.34)
                        .foregroundStyle(Color.warmWhite.opacity(0.4))
                }
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
