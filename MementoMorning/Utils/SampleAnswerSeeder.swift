import Foundation
import SwiftData

/// 動作確認用のサンプル回答を投入する。既に回答が 1 件でもあれば何もしない (冪等)
@MainActor
func seedSampleAnswersIfNeeded(modelContext: ModelContext) {
    // 無料枠 (直近 7 日) の内外両方の見え方を確認するため、今日から 0〜9 日前の 10 件を投入する。
    // 永続化されるサンプルデータのため String(localized:) でアプリの言語に合わせる (.claude/rules/coding-rules-entity.md)
    // Shipaton デモ動画 (issue #94) の題材を兼ねるため、「アプリを作って世界に出すメイカーの 10 日間」
    // のストーリーになっている (index 0 = 今日 = 出荷の日、index 9 = 最も古い = 作り始めの日)
    let sampleTexts = [
        // ja: 自分のアプリを世界に出す
        String(localized: "Ship my app to the world"),
        // ja: Shipaton にアプリを提出する
        String(localized: "Submit my app to the Shipaton"),
        // ja: 納得がいくまで画面を磨く
        String(localized: "Polish every screen until it feels right"),
        // ja: デモ動画を一発撮りする
        String(localized: "Record my demo video in one take"),
        // ja: 徹夜の原因になったバグを直す
        String(localized: "Fix the bug that kept me up all night"),
        // ja: 自作のアラームに初めて答える
        String(localized: "Answer my own alarm for the first time"),
        // ja: 作りかけのアプリを友人に見せる
        String(localized: "Show my rough build to a friend"),
        // ja: ひとつの質問をするアラームを設計する
        String(localized: "Design an alarm that asks one question"),
        // ja: 最初の一行のコードを書く
        String(localized: "Write the first line of code"),
        // ja: 夢に見続けたアプリを作り始める
        String(localized: "Start building the app I keep dreaming about"),
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

/// 「一ヶ月の手紙」の初回無料と 2 通目のプレミアム制限を続けて検証できる 60 日分の回答を投入する。
/// 既に回答が 1 件でもあれば何もしないため、既存データを上書きせず冪等。
@MainActor
func seedOneMonthLetterSampleAnswersIfNeeded(modelContext: ModelContext) {
    do {
        var descriptor = FetchDescriptor<MorningAnswer>()
        descriptor.fetchLimit = 1
        guard try modelContext.fetch(descriptor).isEmpty else { return }

        for index in 0..<(oneMonthLetterAnswerCount * 2) {
            let answeredDate = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: -index, to: .now)!
            )
            let text = if index.isMultiple(of: 2) {
                // ja: 家族とゆっくり過ごす
                String(localized: "Spend unhurried time with my family")
            } else {
                // ja: 家族に電話して、愛していると伝える
                String(localized: "Call my family and tell them I love them")
            }
            modelContext.insert(MorningAnswer(answeredDate: answeredDate, text: text))
        }
        try modelContext.save()
        reloadHomeWidgetTimelines()
    } catch {
        modelContext.rollback()
        assertionFailure(error.localizedDescription)
    }
}
