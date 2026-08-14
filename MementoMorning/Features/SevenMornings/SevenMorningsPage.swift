import SwiftUI
import SwiftData

/// SevenMorningsPage が表示する回答の取得条件。節目の主役である最初の 7 件 (answeredDate 昇順) だけを取得する。
/// ContentView の表示判定 (回答が 7 件に達したか) も件数しか見ないため、この取得条件を共有する。
/// 履歴系クエリのため fetchLimit を設定する (.claude/rules/swiftdata-guidelines.md)
var sevenMorningsAnswersDescriptor: FetchDescriptor<MorningAnswer> {
    var descriptor = FetchDescriptor<MorningAnswer>(
        sortBy: [SortDescriptor(\MorningAnswer.answeredDate, order: .forward)]
    )
    descriptor.fetchLimit = sevenMorningsMilestoneAnswerCount
    return descriptor
}

/// 7 日の節目「七つの朝」。最初の 7 つの回答が初めて 1 画面に並ぶ aha moment の画面。
/// 回答をタップすると共有カード (AnswerShareCardPage) を開く。
/// 7 日の節目は無料の線 (documents/PROJECT.md の課金設計) のため、
/// 未回答日を挟んで 8 日以上前になった回答も AnswerLogVisibility の無料枠制限を適用せずに表示する
struct SevenMorningsPage: View {
    @Query(sevenMorningsAnswersDescriptor) private var answers: [MorningAnswer]

    /// 共有カードを表示する対象の回答
    @State private var shareTargetAnswer: MorningAnswer?

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    // ja: 七つの朝
                    Text("Seven Mornings")
                        .font(.title2)
                        .accessibilityIdentifier("seven_mornings_title")
                    // ja: 七日分の答えが、はじめて一枚に並びました
                    Text("Seven answers, together on one page for the first time.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(answers) { answer in
                        Button {
                            shareTargetAnswer = answer
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(answer.answeredDate, format: .dateTime.year().month().day())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(answer.text)
                                    .font(.body)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // plain スタイルの Button はラベルの描画領域しかタップに反応しないため、
                            // 行全体に広げた透明領域もヒット対象にして行のどこを押しても共有カードを開けるようにする
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .accessibilityIdentifier("seven_mornings_answers")
            }
            .padding(24)
        }
        .sheet(item: $shareTargetAnswer) { answer in
            AnswerShareCardPage(answer: answer)
        }
        .onAppear {
            // Preview では表示済みフラグを書き込まない (開発機 simulator での動作確認の状態を汚さないため)
            if isPreview { return }
            // 表示できた時点で表示済みを記録し、閉じる前にアプリが kill されても再表示しない (一度だけ表示する受け入れ条件)
            UserDefaults.standard.set(true, forKey: .isSevenMorningsMilestonePresented)
        }
    }
}

struct SevenMorningsPage_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        let modelContext = ModelContext(container)
        // 6 日前から今日まで毎朝答えて 7 件に達した状態のサンプルデータ (回答本文はユーザーの自由入力値のためハードコード)
        let _ = {
            let sampleTexts = [
                "家族と海を見に行く",
                "母に長い電話をかける",
                "行きつけの店で好きなものを食べる",
                "友人に手紙を書く",
                "子どもと一日中遊ぶ",
                "誰にも言えなかったことを伝える",
                "朝日を最後まで眺める",
            ]
            for (index, text) in sampleTexts.enumerated() {
                let answeredDate = Calendar.current.startOfDay(
                    for: Calendar.current.date(byAdding: .day, value: index - 6, to: .now)!
                )
                modelContext.insert(MorningAnswer(answeredDate: answeredDate, text: text))
            }
            try! modelContext.save()
        }()
        SevenMorningsPage()
            .modelContainer(container)
    }
}
