import SwiftUI
import SwiftData

/// 朝の問い画面。アラーム発火後に全画面で表示し、「今日死ぬとしたら、何をやりたいか」に答えるまで閉じられないコア画面。
/// 回答が保存される (今日の MorningAnswer が成立する) と当日の残アラーム (バックアップ・追撃含む) を全キャンセルして閉じる。
/// この画面はテキスト入力での回答フローと画面骨格 (issue #4)。第一入力のインカメラ動画回答 (issue #24) は
/// この骨格の上に載る前提で、回答完了の判定は MorningAnswer の成立だけに依存させている。
/// 寝起きの内省の緩和策として、昨日の回答があれば「昨日の回答を今日やる? YES / NO」の選択式から始める
struct MorningQuestionPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// 回答入力テキスト
    @State private var text = ""
    /// 昨日の回答。選択式入力 (昨日の回答を今日やる?) の原資。無ければ最初から自由入力を出す
    @State private var yesterdayAnswer: MorningAnswer?
    /// 昨日の回答の再利用を断った (「別の答えを書く」を選んだ) かどうか。true で自由入力へ切り替える
    @State private var isYesterdayProposalDeclined = false
    /// 保存に失敗した場合のエラー。nil 以外で表示し、再タップで再試行できる
    @State private var saveError: String?
    /// 保存処理 (再スケジュール完了待ち) の実行中かどうか。連打による複数 Task の並行起動を防ぐ
    @State private var isSaving = false
    /// 自由入力欄のフォーカス
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 回答本文 (昨日の回答・自由入力) は長さ制限のない自由入力のため、
            // 本文領域をスクロール可能にして小さい端末や大きな Dynamic Type でも全文を読めるようにする。
            // 操作ボタンはスクロール外の下部固定にして常に押せるようにする
            ScrollView {
                VStack(spacing: 40) {
                    // ja: 今日死ぬとしたら、何をやりたいか
                    Text(String(localized: "If today were your last day, what would you want to do?"))
                        .font(.system(size: 27, weight: .light))
                        .lineSpacing(10)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("morning_question_text")

                    if let yesterdayAnswer, !isYesterdayProposalDeclined {
                        // ja: 昨日の回答を、今日やる?
                        Text(String(localized: "Will you do yesterday's answer today?"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(yesterdayAnswer.text)
                            .font(.system(size: 25, weight: .light))
                            .lineSpacing(12)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("morning_question_yesterday_text")
                    } else {
                        // ja: ここに書く
                        TextField(String(localized: "Type here"), text: $text, axis: .vertical)
                            .font(.system(size: 25, weight: .light))
                            .lineLimit(3...6)
                            .multilineTextAlignment(.center)
                            .focused($isTextFieldFocused)
                            .accessibilityIdentifier("morning_question_text_field")
                    }
                }
                .padding(.top, 110)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 16) {
                if let saveError {
                    // エラーメッセージはそのまま表示する (加工しない)。
                    // 再スケジュール失敗時は最大で登録件数ぶんのエラーが連結されるため、
                    // 行数を制限して操作ボタンを画面外へ押し出さない (全文はアラーム設定画面でも確認できる)
                    Text(saveError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .accessibilityIdentifier("morning_question_save_error")
                }

                if let yesterdayAnswer, !isYesterdayProposalDeclined {
                    Button {
                        save(text: yesterdayAnswer.text)
                    } label: {
                        // ja: やる
                        Text(String(localized: "I will"))
                    }
                    .buttonStyle(PrimaryPillButtonStyle())
                    .disabled(isSaving)
                    .accessibilityIdentifier("morning_question_yes_button")

                    Button {
                        isYesterdayProposalDeclined = true
                        isTextFieldFocused = true
                    } label: {
                        // ja: 別の答えを書く
                        Text(String(localized: "Write a different answer"))
                    }
                    .buttonStyle(SecondaryPillButtonStyle())
                    .accessibilityIdentifier("morning_question_no_button")
                } else {
                    Button {
                        save(text: text)
                    } label: {
                        // ja: これで確定する
                        Text(String(localized: "Make it today's answer"))
                    }
                    .buttonStyle(PrimaryPillButtonStyle())
                    .disabled(isSaving || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("morning_question_submit_button")
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        // 静かな世界観の墨色背景 (design_handoff_memento_morning/README.md の Design Tokens)
        .background(Color.ink.ignoresSafeArea())
        .foregroundStyle(Color.warmWhite)
        .onAppear {
            yesterdayAnswer = fetchMorningAnswer(
                answeredDate: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
                modelContext: modelContext
            )
        }
    }

    /// 回答を保存し、当日の残アラームを全キャンセルして画面を閉じる。
    /// 保存・再スケジュールに失敗した時は、止まったと誤解させないよう閉じずにエラーを表示する (再タップで再試行)
    private func save(text: String) {
        guard !isSaving else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        saveError = nil

        // 同じ日の回答は 1 件に保つ (再入・レース時は既存回答の更新にする)。
        // 既存回答の取得失敗を未回答と誤認すると同じ日の回答を重複挿入してしまうため、
        // throwing 版で取得し、失敗は保存エラーと同じ扱いで中断する
        let today = Calendar.current.startOfDay(for: .now)
        do {
            if let answer = try MorningAnswer.answer(day: today, calendar: .current, modelContext: modelContext) {
                answer.setText(text: trimmed)
            } else {
                modelContext.insert(MorningAnswer(answeredDate: today, text: trimmed))
            }
            try modelContext.save()
        } catch {
            // 永続化されていない変更を mainContext に残すと、次回の reschedule がその未保存の値を fetch してしまうため、
            // 変更を破棄してから中断する
            modelContext.rollback()
            saveError = "\(error)"
            isSaving = false
            return
        }

        Task {
            // 回答の成立 → 当日の全アラーム (バックアップ・追撃含む) のキャンセル。
            // reschedule は回答済みの日を計画から除くため、全キャンセル → 全再登録で当日分だけが消える
            await reschedule(modelContext: modelContext)
            if let error = UserDefaults.standard.string(forKey: .lastRescheduleError) {
                saveError = error
                isSaving = false
            } else {
                dismiss()
            }
        }
    }
}

/// MorningQuestionPage の Preview
struct MorningQuestionPage_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        let modelContext = ModelContext(container)
        // 昨日の回答がある状態のプレビュー (選択式入力から始まる)
        let _ = modelContext.insert(
            MorningAnswer(
                answeredDate: Calendar.current.startOfDay(
                    for: Calendar.current.date(byAdding: .day, value: -1, to: .now)!
                ),
                text: "家族と海を見に行く"
            )
        )
        let _ = try! modelContext.save()

        MorningQuestionPage()
            .modelContainer(container)
    }
}
