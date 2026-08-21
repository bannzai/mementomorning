import Foundation
import SwiftData

#if DEBUG
/// 動作確認用のサンプル回答を投入する。既に回答が 1 件でもあれば何もしない (冪等)
@MainActor
func seedSampleAnswersIfNeeded(modelContext: ModelContext) {
    // 無料枠 (直近 7 日) の内外両方の見え方を確認するため、今日から 0〜9 日前の 10 件を投入する。
    // 永続化されるサンプルデータのため String(localized:) でアプリの言語に合わせる (.claude/rules/coding-rules-entity.md)
    let sampleTexts = [
        // ja: 家族と海を見に行く
        String(localized: "See the ocean with my family"),
        // ja: 母に長い電話をかける
        String(localized: "Have a long phone call with my mother"),
        // ja: 行きつけの店で好きなものを食べる
        String(localized: "Eat my favorite meal at my usual place"),
        // ja: 友人に手紙を書く
        String(localized: "Write a letter to a friend"),
        // ja: 子どもと一日中遊ぶ
        String(localized: "Play with my kids all day"),
        // ja: 誰にも言えなかったことを伝える
        String(localized: "Say the things I've never been able to say"),
        // ja: 朝日を最後まで眺める
        String(localized: "Watch the sunrise to the very end"),
        // ja: 育てた庭の手入れをする
        String(localized: "Tend the garden I've grown"),
        // ja: 昔の仲間に会いに行く
        String(localized: "Visit my old friends"),
        // ja: 自分の言葉を書き残す
        String(localized: "Leave my own words behind"),
    ]
    do {
        var descriptor = FetchDescriptor<MorningAnswer>()
        descriptor.fetchLimit = 1
        guard try modelContext.fetch(descriptor).isEmpty else {
            return
        }
        for (index, text) in sampleTexts.enumerated() {
            let answeredDate = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: -index, to: .now)!
            )
            modelContext.insert(MorningAnswer(answeredDate: answeredDate, text: text))
        }
        try modelContext.save()
        // 投入したサンプルの今日の回答をホーム画面ウィジェットへ反映する (issue #46)
        reloadHomeWidgetTimelines()
    } catch {
        assertionFailure(error.localizedDescription)
    }
}
#endif
