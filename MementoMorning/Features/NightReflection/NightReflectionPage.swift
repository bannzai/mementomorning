import SwiftUI
import SwiftData

/// 夜の振り返り画面。夜リマインドから開き、今朝の回答と答え合わせしてループを閉じる
struct NightReflectionPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var answer: MorningAnswer?

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
            answer = todayAnswer()
        }
    }

    /// 今日 (0 時基準) の回答を取得する。1 日 1 件のため 1 件だけ取得する
    private func todayAnswer() -> MorningAnswer? {
        let today = Calendar.current.startOfDay(for: .now)
        var descriptor = FetchDescriptor<MorningAnswer>(predicate: #Predicate { $0.answeredDate == today })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// 夜の振り返りを記録して画面を閉じる
    private func record(isFulfilled: Bool) {
        answer?.setFulfilled(isFulfilled: isFulfilled)
        try? modelContext.save()
        dismiss()
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

        NightReflectionPage()
            .modelContainer(container)
    }
}
