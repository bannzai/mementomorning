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

/// 答えた朝が一粒ずつ墨のように埋まっていく人生カレンダー (週単位グリッド)。1 行が 1 週間、1 マスが 1 日
///
/// 墨の粒の見た目はデザイン反映 (issue #12) までの仮実装。
/// 空白の日は空白のまま残す (streak 修復は作らない。documents/PROJECT.md の課金設計参照)
struct LifeCalendarPage: View {
    @Query(lifeCalendarAnswersDescriptor) private var answers: [MorningAnswer]

    var body: some View {
        let calendar = Calendar.current
        let answeredDays = Set(answers.map { calendar.startOfDay(for: $0.answeredDate) })
        ScrollView {
            // 粒の大きさ 12pt・間隔 8pt はデザイン反映 (issue #12) までの仮の値
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(12), spacing: 8), count: 7), spacing: 8) {
                ForEach(lifeCalendarDays(answeredDates: answers.map(\.answeredDate), today: .now, calendar: calendar), id: \.self) { day in
                    Circle()
                        .fill(answeredDays.contains(day) ? HierarchicalShapeStyle.primary : HierarchicalShapeStyle.quaternary)
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.vertical, 16)
        }
    }
}

struct LifeCalendarPage_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        let modelContext = ModelContext(container)
        // 今日・3 日前・10 日前に回答した状態のサンプルデータ (回答本文はユーザーの自由入力値のためハードコード)
        let _ = {
            let calendar = Calendar.current
            modelContext.insert(MorningAnswer(answeredDate: calendar.startOfDay(for: .now), text: "家族と過ごす"))
            modelContext.insert(MorningAnswer(answeredDate: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -3, to: .now)!), text: "海を見に行く"))
            modelContext.insert(MorningAnswer(answeredDate: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -10, to: .now)!), text: "手紙を書く"))
            try! modelContext.save()
        }()
        LifeCalendarPage()
            .modelContainer(container)
    }
}
