import SwiftUI
import SwiftData

/// 夜の振り返り画面。夜リマインドから開き、今朝の回答と答え合わせしてループを閉じる
struct NightReflectionPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// 振り返りの対象日を決める、夜リマインドが配信された日時。日付が変わってからタップされてもこの日時の回答を振り返る
    let notificationDate: Date

    @State private var answer: MorningAnswer?
    /// 直前の記録が保存に失敗したかどうか。true の間はエラーを表示したまま画面に留まり、再タップで再試行できる
    @State private var isSaveFailed = false

    var body: some View {
        VStack(spacing: 32) {
            if let answer {
                // ja: 守れてますか?
                Text(String(localized: "Are you keeping it?"))
                    .font(.title2)
                    .multilineTextAlignment(.center)

                Text(answer.text)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("night_reflection_answer_text")

                if let isFulfilled = answer.isFulfilled {
                    // ja: 記録済み: %@
                    Text("Recorded: \(isFulfilled ? Text("I did") : Text("Not yet"))")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                VStack(spacing: 12) {
                    Button {
                        record(isFulfilled: true)
                    } label: {
                        // ja: やれた
                        Text(String(localized: "I did"))
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("night_reflection_fulfilled_button")

                    Button {
                        record(isFulfilled: false)
                    } label: {
                        // ja: やれていない
                        Text(String(localized: "Not yet"))
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("night_reflection_not_fulfilled_button")

                    if isSaveFailed {
                        // ja: 保存に失敗しました。もう一度お試しください
                        Text(String(localized: "Failed to save. Please try again."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("night_reflection_save_error")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            } else {
                // ja: 今朝の回答はまだありません
                Text(String(localized: "No answer this morning yet."))
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button {
                    dismiss()
                } label: {
                    // ja: 閉じる
                    Text(String(localized: "Close"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .onAppear {
            answer = notificationDayAnswer()
        }
    }

    /// 通知が配信された日 (0 時基準) の回答を取得する。1 日 1 件のため 1 件だけ取得する
    private func notificationDayAnswer() -> MorningAnswer? {
        let notificationDay = Calendar.current.startOfDay(for: notificationDate)
        var descriptor = FetchDescriptor<MorningAnswer>(predicate: #Predicate { $0.answeredDate == notificationDay })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// 夜の振り返りを記録して画面を閉じる。保存に失敗した時は記録できたと誤解させないよう閉じずにエラーを表示する
    private func record(isFulfilled: Bool) {
        isSaveFailed = false
        answer?.setFulfilled(isFulfilled: isFulfilled)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("[NightReflectionPage] failed to save night reflection: \(error)")
            isSaveFailed = true
        }
    }
}

struct NightReflectionPage_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        let modelContext = ModelContext(container)
        // 今朝の回答がある状態のプレビュー
        let _ = modelContext.insert(
            MorningAnswer(answeredDate: Calendar.current.startOfDay(for: .now), text: "家族と海を見に行く")
        )
        let _ = try! modelContext.save()

        NightReflectionPage(notificationDate: .now)
            .modelContainer(container)
    }
}
