import Foundation
import SwiftData

#if DEBUG
/// 動作確認用のサンプル回答を投入する。既に回答が 1 件でもあれば何もしない (冪等)
@MainActor
func seedSampleAnswersIfNeeded(modelContext: ModelContext) {
    // 無料枠 (直近 7 日) の内外両方の見え方を確認するため、今日から 0〜9 日前の 10 件を投入する
    let sampleTexts = [
        "家族と海を見に行く",
        "母に長い電話をかける",
        "行きつけの店で好きなものを食べる",
        "友人に手紙を書く",
        "子どもと一日中遊ぶ",
        "誰にも言えなかったことを伝える",
        "朝日を最後まで眺める",
        "育てた庭の手入れをする",
        "昔の仲間に会いに行く",
        "自分の言葉を書き残す",
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
