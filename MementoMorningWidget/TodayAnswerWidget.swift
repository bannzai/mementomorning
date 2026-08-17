import WidgetKit
import SwiftUI
import SwiftData

/// ホーム画面ウィジェットのタイムラインエントリ。表示時点の今日の回答本文を持つ
struct TodayAnswerEntry: TimelineEntry {
    /// エントリの表示開始日時
    let date: Date
    /// 今日の回答本文。未回答 (または取得失敗) なら nil
    let answerText: String?
}

/// 今日の回答をウィジェットへ供給する TimelineProvider
struct TodayAnswerProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayAnswerEntry {
        // ja: 家族と海を見に行く
        TodayAnswerEntry(date: .now, answerText: String(localized: "Go see the ocean with my family"))
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayAnswerEntry) -> Void) {
        completion(TodayAnswerEntry(date: .now, answerText: fetchTodayAnswerText()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayAnswerEntry>) -> Void) {
        let now = Date.now
        // 「今日の回答」の表示は日付が変わると古くなるため、次の 0 時にタイムラインを作り直して
        // 未回答表示へ自動で戻す。回答の保存時はアプリ側の reloadAllTimelines() が即時反映する
        completion(Timeline(
            entries: [TodayAnswerEntry(date: now, answerText: fetchTodayAnswerText())],
            policy: .after(homeWidgetReloadDate(now: now, calendar: .current))
        ))
    }

    /// 今日の回答本文を App Groups 共有ストアから取得する。未回答・取得失敗は nil (未回答表示にする)
    private func fetchTodayAnswerText() -> String? {
        // TimelineProvider は nonisolated のため @MainActor の PersistenceController.shared には触れない。
        // アプリと同じスキーマ・設定で container を関数内ローカルに作って同期的にアクセスする
        // (プロパティとして保持しない。swiftdata-guidelines「App Extension 内での SwiftData」参照)
        guard let container = try? ModelContainer(
            for: PersistenceController.schema,
            configurations: PersistenceController.configuration
        ) else { return nil }
        return (try? MorningAnswer.answer(
            day: .now,
            calendar: .current,
            modelContext: ModelContext(container)
        ))??.text
    }
}

/// ウィジェットの表示ビュー。アプリと同じ静かな世界観 (墨地・温白・アクセントなし) で描く
struct TodayAnswerWidgetView: View {
    /// 表示するタイムラインエントリ
    let entry: TodayAnswerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ja: 今日死ぬとしたら、何をやりたいか
            Text("If today were your last day, what would you want to do?")
                .font(.system(size: 11, weight: .regular))
                .tracking(0.55)
                .lineSpacing(11 * 0.35)
                .foregroundStyle(Color.warmWhite.opacity(0.55))
            Spacer(minLength: 0)
            if let answerText = entry.answerText {
                Text(answerText)
                    .font(.system(size: 16, weight: .light))
                    .tracking(0.8)
                    .lineSpacing(16 * 0.35)
                    .foregroundStyle(Color.warmWhite)
            } else {
                // ja: まだ答えていない
                Text("Not answered yet")
                    .font(.system(size: 13, weight: .light))
                    .tracking(0.65)
                    .foregroundStyle(Color.warmWhite.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color.ink, for: .widget)
    }
}

/// 今日の回答をホーム画面に常駐させるウィジェット (issue #46)。タップでアプリを開く標準挙動のみで、操作は持たない
struct TodayAnswerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: todayAnswerWidgetKind, provider: TodayAnswerProvider()) { entry in
            TodayAnswerWidgetView(entry: entry)
        }
        // ja: 今日の答え
        .configurationDisplayName("Today's Answer")
        // ja: 今日の答えをホーム画面に置いておく
        .description("Keep today's answer on your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
