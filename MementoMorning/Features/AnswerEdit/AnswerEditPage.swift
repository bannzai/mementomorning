import SwiftUI
import SwiftData

/// 回答本文の編集画面 (sheet 表示)。
/// 動画回答の文字起こし (VideoAnswerTranscriber) の誤認識を直す導線が主用途で、テキスト回答の書き直しにも使う
struct AnswerEditPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// 編集対象の回答
    let answer: MorningAnswer

    /// 編集中の回答本文
    @State private var text: String
    /// 保存に失敗した場合のエラー。nil 以外で表示し、再タップで再試行できる
    @State private var saveError: String?

    /// 編集中の本文の初期値を編集対象の回答から与えるため、明示的に init を定義する
    init(answer: MorningAnswer) {
        self.answer = answer
        _text = State(initialValue: answer.text)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 回答は長さ制限のない自由入力のため、本文領域をスクロール可能にして
            // 小さい端末や大きな Dynamic Type でも全文を編集できるようにする
            ScrollView {
                VStack(spacing: 32) {
                    // ja: 今朝のことば
                    Text("This morning's words")
                        .font(.system(size: 10))
                        .tracking(2.2)
                        .foregroundStyle(Color.dawn)
                    // ja: ここに書く
                    TextField(String(localized: "Type here"), text: $text, axis: .vertical)
                        .font(.system(size: 25, weight: .light))
                        .lineLimit(3...10)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("answer_edit_text_field")
                }
                .padding(.top, 64)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 16) {
                if let saveError {
                    // エラーメッセージはそのまま表示する (加工しない)。
                    // 行数を制限して保存ボタンを画面外へ押し出さない
                    Text(saveError)
                        .font(.footnote)
                        .foregroundStyle(Color.warmWhite.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .accessibilityIdentifier("answer_edit_save_error")
                }
                Button {
                    save()
                } label: {
                    // ja: 保存
                    Text("Save")
                }
                .buttonStyle(PrimaryPillButtonStyle())
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("answer_edit_save_button")
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(Color.ink.ignoresSafeArea())
        .foregroundStyle(Color.warmWhite)
    }

    /// 編集した本文を保存して閉じる。保存に失敗した時は、直ったと誤解させないよう閉じずにエラーを表示する (再タップで再試行)
    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saveError = nil
        answer.setText(text: trimmed)
        do {
            try modelContext.save()
        } catch {
            // 永続化されていない変更を mainContext に残すと、次回の reschedule がその未保存の値を fetch してしまうため破棄する
            modelContext.rollback()
            saveError = "\(error)"
            return
        }
        dismiss()
    }
}

struct AnswerEditPage_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        let modelContext = ModelContext(container)
        // 文字起こし直後の今日の回答を直すサンプル
        let answer: MorningAnswer = {
            // Preview の body は複数回評価されるため、共有 in-memory コンテナへの重複挿入を防いで冪等にする
            if let answer = try? modelContext.fetch(FetchDescriptor<MorningAnswer>()).first {
                return answer
            }
            let answer = MorningAnswer(answeredDate: Calendar.current.startOfDay(for: .now), text: "家族と海を見に行く")
            modelContext.insert(answer)
            try! modelContext.save()
            return answer
        }()

        AnswerEditPage(answer: answer)
            .modelContainer(container)
    }
}
