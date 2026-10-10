import SwiftData
import SwiftUI

/// 90 日の節目「問い直し」。1 件目の回答と 90 件目の回答を左右に並べ、問いを 1 行だけ添える全画面 (issue #187)。
/// 炎・バッジ・紙吹雪・数値カウンターは置かない (documents/PROJECT.md の世界観の制約)。
/// 動画回答は文字起こしが本文 (text) に入っているためそのまま並べ、文字起こしが無い時は本文の仮テキストが代替表示になる
struct QuestionRevisitPage: View {
    @Environment(\.dismiss) private var dismiss
    @Query(questionRevisitAnswerDescriptor(number: 1)) private var firstAnswers: [MorningAnswer]
    @Query(questionRevisitAnswerDescriptor(number: questionRevisitMilestoneAnswerCount)) private var ninetiethAnswers: [MorningAnswer]
    @AppStorage(.isQuestionRevisitMilestonePresented) private var isQuestionRevisitMilestonePresented = false

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    if let firstAnswer = firstAnswers.first, let ninetiethAnswer = ninetiethAnswers.first {
                        HStack(alignment: .top, spacing: 24) {
                            answerColumn(answer: firstAnswer)
                                .accessibilityIdentifier("question_revisit_first_answer")
                            Rectangle()
                                .fill(Color.dawn.opacity(0.45))
                                .frame(width: 1)
                            answerColumn(answer: ninetiethAnswer)
                                .accessibilityIdentifier("question_revisit_ninetieth_answer")
                        }
                        .padding(.top, 96)
                    }

                    // ja: あなたの答えは変わりましたか
                    Text("Has your answer changed?")
                        .font(.system(size: 24, weight: .light, design: .serif))
                        .foregroundStyle(Color.warmWhite)
                        .multilineTextAlignment(.center)
                        .padding(.top, 64)
                        .accessibilityIdentifier("question_revisit_title")

                    Button {
                        dismiss()
                    } label: {
                        // ja: 今朝へ戻る
                        Text("Return to this morning")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(1.1)
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.dawn)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("question_revisit_close_button")
                    .padding(.top, 54)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 34)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            // Preview では表示済みフラグを書き込まない (開発機 simulator での動作確認の状態を汚さないため)
            if isPreview { return }
            // 表示できた時点で表示済みを記録し、閉じる前にアプリが kill されても再表示しない (何度表示しても true に収束するため冪等)
            isQuestionRevisitMilestonePresented = true
        }
    }

    /// 片側の回答 (答えた日と本文)。日付を見出しにして、何件目かの数字を見せない
    private func answerColumn(answer: MorningAnswer) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(answer.answeredDate, format: .dateTime.year().month().day())
                .font(.system(size: 10, weight: .medium))
                .tracking(1.6)
                .foregroundStyle(Color.dawn.opacity(0.8))
            Text(answer.text)
                .font(.system(size: 17, weight: .light, design: .serif))
                .foregroundStyle(Color.warmWhite)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QuestionRevisitPage_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        let modelContext = ModelContext(container)
        let _ = {
            // Preview の再評価で重複しないよう、空の時だけ 90 日分のデータを作る (回答本文はユーザーの自由入力値のためハードコード)
            guard (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) == 0 else { return }
            for index in 0..<questionRevisitMilestoneAnswerCount {
                let date = Calendar.current.date(byAdding: .day, value: index - questionRevisitMilestoneAnswerCount + 1, to: .now)!
                modelContext.insert(MorningAnswer(answeredDate: date, text: index == 0 ? "夢に見続けたアプリを作り始める" : "自分のアプリを世界に出す"))
            }
            try! modelContext.save()
        }()
        QuestionRevisitPage()
            .modelContainer(container)
    }
}
