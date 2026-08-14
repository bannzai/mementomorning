import SwiftUI
import SwiftData

/// 回答ログ (ジャーナル) 画面。蓄積された MorningAnswer を新しい順に一覧表示する
struct AnswerLogPage: View {
    @Query private var answers: [MorningAnswer]

    /// 共有カードを表示する対象の回答
    @State private var shareTargetAnswer: MorningAnswer?

    /// ペイウォールを表示中かどうか。無料枠で隠れている回答の案内行タップで開く
    @State private var isPaywallPresented = false

    /// RevenueCat の entitlement キャッシュ。値の変化で再描画を起こすために監視する (判定は PremiumEntitlement.isPremium が SSOT)
    @AppStorage(.premiumEntitlementActive) private var premiumEntitlementActive = false
    #if DEBUG
    /// 検証用のプレミアム強制フラグ。値の変化で再描画を起こすために監視する
    @AppStorage(.debugPremiumOverride) private var debugPremiumOverride = false
    #endif

    /// fetchLimit 付きの FetchDescriptor を組み立てるため、明示的に init を定義する
    init() {
        var descriptor = FetchDescriptor<MorningAnswer>(
            sortBy: [SortDescriptor(\MorningAnswer.answeredDate, order: .reverse)]
        )
        // 365 日の節目「365 の朝」の 1 年分 + 今日を表示上限の最大想定とするため 366 件
        descriptor.fetchLimit = 366
        _answers = Query(descriptor)
    }

    var body: some View {
        Group {
            if visibleAnswers.isEmpty {
                // ja: 回答は、ひと朝ずつここに集まっていきます
                Text("Your answers will gather here, one morning at a time.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                List {
                    ForEach(visibleAnswers) { answer in
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
                    if hiddenAnswerCount > 0 {
                        // 無料枠で隠れている回答の案内。タップでペイウォールを開く (design handoff「ジャーナルのロック行タップ → ペイウォール」)
                        Button {
                            isPaywallPresented = true
                        } label: {
                            // ja: 8 日以上前の回答はプレミアムで解放されます
                            Text("Answers older than 7 days unlock with Premium.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityIdentifier("answer_log_locked_row")
                    }
                }
                .listStyle(.plain)
            }
        }
        // ja: ジャーナル
        .navigationTitle(Text("Journal"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareTargetAnswer) { answer in
            AnswerShareCardPage(answer: answer)
        }
        .sheet(isPresented: $isPaywallPresented) {
            PaywallPage()
        }
    }

    /// 現在の課金状態で閲覧できる回答
    private var visibleAnswers: [MorningAnswer] {
        answers.filter {
            AnswerLogVisibility.isVisible(answeredDate: $0.answeredDate, isPremium: PremiumEntitlement.isPremium)
        }
    }

    /// 無料枠で隠れている回答数
    private var hiddenAnswerCount: Int { answers.count - visibleAnswers.count }
}

struct AnswerLogPage_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        let modelContext = ModelContext(container)
        // 直近 7 日以内の回答 2 件 + 8 日以上前の回答 1 件 (無料状態では見えない) のサンプル
        let _ = {
            modelContext.insert(MorningAnswer(answeredDate: .now, text: "家族と海を見に行く"))
            modelContext.insert(MorningAnswer(answeredDate: Calendar.current.date(byAdding: .day, value: -3, to: .now)!, text: "友人に手紙を書く"))
            modelContext.insert(MorningAnswer(answeredDate: Calendar.current.date(byAdding: .day, value: -10, to: .now)!, text: "山に登る"))
            try! modelContext.save()
        }()
        NavigationStack {
            AnswerLogPage()
        }
        .modelContainer(container)
    }
}
