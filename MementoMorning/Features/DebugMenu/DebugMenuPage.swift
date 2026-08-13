import SwiftUI
import SwiftData

#if DEBUG
/// 開発者メニュー。動作確認・E2E テストで到達困難な状態を作るための DEBUG 限定ページ
/// (.claude/rules/debug-menu-for-verification.md 参照。リモート simulator からも操作できるようアプリ内 UI で提供する)
struct DebugMenuPage: View {
    @Environment(\.modelContext) private var modelContext

    /// 現在の回答件数。デバッグ操作の結果を画面上で確認できるように表示する
    @State private var morningAnswerCount = 0

    var body: some View {
        List {
            Section {
                Text(verbatim: "MorningAnswer: \(morningAnswerCount)")
                    .accessibilityIdentifier("debug_morning_answer_count")
            }
            Section {
                Button {
                    seedSampleAnswersIfNeeded(modelContext: modelContext)
                    refreshMorningAnswerCount()
                } label: {
                    Text(verbatim: "Seed sample answers (10 days)")
                }
                .accessibilityIdentifier("debug_seed_sample_answers")

                Button(role: .destructive) {
                    deleteAllMorningAnswers()
                    refreshMorningAnswerCount()
                } label: {
                    Text(verbatim: "Delete all answers")
                }
                .accessibilityIdentifier("debug_delete_all_answers")
            }
        }
        .navigationTitle(Text(verbatim: "Developer Menu"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshMorningAnswerCount()
        }
    }

    /// 回答件数の表示を最新化する
    private func refreshMorningAnswerCount() {
        morningAnswerCount = (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) ?? 0
    }

    /// 全回答を削除する (空の状態からやり直すためのデバッグ操作。空なら何もせず冪等)
    private func deleteAllMorningAnswers() {
        do {
            try modelContext.delete(model: MorningAnswer.self)
            try modelContext.save()
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }
}

struct DebugMenuPage_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DebugMenuPage()
        }
        .modelContainer(PersistenceController.shared.container)
    }
}
#endif
