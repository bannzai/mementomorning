import SwiftData
import SwiftUI

/// 指定した通数に対応する 30 件だけを古い順で取得する。
/// 履歴系クエリのため fetchLimit を設定する (.claude/rules/swiftdata-guidelines.md)。
func oneMonthLetterAnswersDescriptor(milestoneNumber: Int) -> FetchDescriptor<MorningAnswer> {
    var descriptor = FetchDescriptor<MorningAnswer>(
        sortBy: [SortDescriptor(\MorningAnswer.answeredDate, order: .forward)]
    )
    descriptor.fetchOffset = (max(1, milestoneNumber) - 1) * oneMonthLetterAnswerCount
    descriptor.fetchLimit = oneMonthLetterAnswerCount
    return descriptor
}

/// 30 回分の回答から端末内で頻出語を見つけ、アプリからの手紙として届ける節目画面。
struct OneMonthLetterPage: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var answers: [MorningAnswer]
    @AppStorage(.lastPresentedOneMonthLetterNumber) private var lastPresentedNumber = 0

    let milestoneNumber: Int

    init(milestoneNumber: Int) {
        self.milestoneNumber = milestoneNumber
        _answers = Query(oneMonthLetterAnswersDescriptor(milestoneNumber: milestoneNumber))
    }

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    Text(verbatim: "LETTER \(milestoneNumber)")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(3.2)
                        .foregroundStyle(Color.dawn.opacity(0.8))
                        .padding(.top, 72)

                    // ja: あなたが重ねた朝からの手紙
                    Text("A Letter from Your Mornings")
                        .font(.system(size: 34, weight: .light, design: .serif))
                        .foregroundStyle(Color.warmWhite)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                        .accessibilityIdentifier("one_month_letter_title")

                    // ja: 30回の朝を重ねました。
                    Text("Thirty mornings have passed.")
                        .font(.system(size: 15, weight: .light))
                        .tracking(0.45)
                        .foregroundStyle(Color.warmWhite.opacity(0.58))
                        .padding(.top, 12)

                    Rectangle()
                        .fill(Color.dawn.opacity(0.45))
                        .frame(width: 40, height: 1)
                        .padding(.vertical, 42)

                    if let keyword {
                        // ja: あなたの答えには、何度も現れる言葉がありました。
                        Text("Across your answers, one word kept returning.")
                            .font(.system(size: 16, weight: .light, design: .serif))
                            .foregroundStyle(Color.warmWhite.opacity(0.72))
                            .multilineTextAlignment(.center)

                        Text(verbatim: "“\(keyword)”")
                            .font(.system(size: 44, weight: .light, design: .serif))
                            .foregroundStyle(Color.dawn)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.65)
                            .padding(.vertical, 34)
                            .accessibilityIdentifier("one_month_letter_keyword")

                        // ja: それは、あなたが大切にしたいと願い続けていたものかもしれません。
                        Text("Maybe it is what you have kept wanting to hold close.")
                            .font(.system(size: 16, weight: .light, design: .serif))
                            .foregroundStyle(Color.warmWhite.opacity(0.72))
                            .multilineTextAlignment(.center)
                    } else {
                        // ja: あなたの言葉は今も、ゆっくり形になりつつあります。
                        Text("Your words are still slowly taking shape.")
                            .font(.system(size: 16, weight: .light, design: .serif))
                            .foregroundStyle(Color.warmWhite.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        dismiss()
                    } label: {
                        // ja: この言葉と歩いていく
                        Text("Carry it with me")
                            .font(.system(size: 13, weight: .medium))
                            .tracking(1.1)
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.dawn)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("one_month_letter_close_button")
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
            // 表示できた時点まで進める。再描画されても同じ最大値へ収束するため冪等。
            lastPresentedNumber = max(lastPresentedNumber, milestoneNumber)
        }
    }

    private var keyword: String? {
        mostFrequentMeaningfulWord(
            in: answers
                .filter { $0.videoTranscriptionStatus != .failed }
                .map(\.text)
        )
    }
}

struct OneMonthLetterPage_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        let modelContext = ModelContext(container)
        let _ = {
            // Preview の再評価で重複しないよう、空の時だけ最初の手紙用データを作る。
            guard (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) == 0 else { return }
            for index in 0..<oneMonthLetterAnswerCount {
                let date = Calendar.current.date(byAdding: .day, value: index - oneMonthLetterAnswerCount + 1, to: .now)!
                modelContext.insert(MorningAnswer(answeredDate: date, text: "Spend time with my family"))
            }
            try! modelContext.save()
        }()
        OneMonthLetterPage(milestoneNumber: 1)
            .modelContainer(container)
    }
}
