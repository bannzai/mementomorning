import SwiftUI
import SwiftData

/// 回答ログ (ジャーナル) 画面。デザイン handoff 1f / プロトタイプ journal 準拠。
/// 蓄積された MorningAnswer を新しい順に、日付 + 回答 + 夜の結果のヘアライン区切りで一覧表示する
struct AnswerLogPage: View {
    @Query private var answers: [MorningAnswer]

    /// 共有カードを表示する対象の回答
    @State private var shareTargetAnswer: MorningAnswer?
    /// 動画の再生画面 (AnswerVideoPlayerPage) を開く対象の動画 (issue #80)
    @State private var replayTargetVideo: VideoAnswerReplayTarget?
    /// ペイウォールの表示状態。無料枠のロック行から開く
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
            // 非表示回答だけが残っている場合 (無料枠で全件が 7 日より前) も、
            // ペイウォール導線 (lockFooter) に到達できるようリスト側の分岐へ流す
            if visibleAnswers.isEmpty && hiddenAnswerCount == 0 {
                // ja: 回答は、ひと朝ずつここに集まっていきます
                Text("Your answers will gather here, one morning at a time.")
                    .font(.system(size: 14, weight: .light))
                    .tracking(0.42)
                    .foregroundStyle(Color.warmWhite.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleAnswers) { answer in
                            answerRow(answer: answer)
                        }
                        if hiddenAnswerCount > 0 {
                            lockFooter
                        }
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
        .background(Color.ink.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 3) {
                    // ja: ジャーナル
                    Text("Journal")
                        .font(.system(size: 15, weight: .medium))
                        .tracking(2.1)
                        .foregroundStyle(Color.warmWhite)
                    Text(verbatim: "JOURNAL")
                        .font(.system(size: 9))
                        .tracking(2.34)
                        .foregroundStyle(Color.warmWhite.opacity(0.4))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareTargetAnswer) { answer in
            AnswerShareCardPage(answer: answer)
        }
        .sheet(item: $replayTargetVideo) { target in
            AnswerVideoPlayerPage(videoAssetIdentifier: target.videoAssetIdentifier)
        }
        .sheet(isPresented: $isPaywallPresented) {
            PaywallPage()
        }
    }

    /// 回答 1 行 (日付 + 夜の結果 + 回答本文、ヘアライン区切り)。タップで共有カードを開く。
    /// 動画で答えた行は本文の下に「動画を見返す」導線を添え、再生画面を開く (issue #80)
    private func answerRow(answer: MorningAnswer) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            shareCardButton(answer: answer)
            if let videoAssetIdentifier = answer.videoAssetIdentifier {
                Button {
                    replayTargetVideo = VideoAnswerReplayTarget(videoAssetIdentifier: videoAssetIdentifier)
                } label: {
                    // ja: 動画を見返す
                    Text("Watch the video")
                        .font(.system(size: 11))
                        .tracking(1.1)
                        .foregroundStyle(Color.warmWhite.opacity(0.4))
                        .underline()
                        .padding(.bottom, 19)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("journal_video_replay_link")
            }
        }
        .overlay(alignment: .bottom) {
            HairlineDivider()
        }
    }

    /// 回答本文の部分 (日付 + 夜の結果 + 回答本文)。タップで共有カードを開く
    private func shareCardButton(answer: MorningAnswer) -> some View {
        let isToday = Calendar.current.isDateInToday(answer.answeredDate)
        return Button {
            shareTargetAnswer = answer
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Group {
                        if isToday {
                            // ja: 今日
                            Text("Today")
                        } else {
                            Text(answer.answeredDate, format: .dateTime.year().month().day())
                        }
                    }
                    .font(.system(size: 11))
                    .tracking(1.1)
                    // 今日の行の日付だけ夜明け色 (アクセントは各画面 1 箇所まで)
                    .foregroundStyle(isToday ? Color.dawn : Color.warmWhite.opacity(0.38))
                    Spacer()
                    // 過去の行の右端に夜の振り返りの結果を添える。未記録の行には何も表示しない
                    if !isToday, let isFulfilled = answer.isFulfilled {
                        Group {
                            if isFulfilled {
                                // ja: やれた
                                Text("I did")
                            } else {
                                Text(verbatim: "—")
                            }
                        }
                        .font(.system(size: 10))
                        .tracking(1.0)
                        .foregroundStyle(Color.warmWhite.opacity(0.35))
                    }
                }
                Text(answer.text)
                    .font(.system(size: 17, weight: .light))
                    .tracking(0.51)
                    .lineSpacing(17 * 0.6)
                    .foregroundStyle(Color.warmWhite)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 19)
            // 動画の行は「動画を見返す」導線が下の余白を受け持つため、本文側の下余白を詰める
            .padding(.bottom, answer.videoAssetIdentifier == nil ? 19 : 10)
            // plain スタイルの Button はラベルの描画領域しかタップに反応しないため、
            // 行全体に広げた透明領域もヒット対象にして行のどこを押しても共有カードを開けるようにする
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 無料枠のロック行。タップでペイウォールを開く
    private var lockFooter: some View {
        Button {
            isPaywallPresented = true
        } label: {
            VStack(spacing: 5) {
                // ja: 7日より前の朝は、プレミアムで。
                Text("Older mornings unlock with Premium.")
                    .font(.system(size: 12))
                    .tracking(0.96)
                    .foregroundStyle(Color.warmWhite.opacity(0.45))
                // ja: すべての朝を見る
                Text("See every morning")
                    .font(.system(size: 10))
                    .tracking(0.6)
                    .foregroundStyle(Color.dawn)
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("journal_paywall_link")
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
        // 直近 7 日以内の回答 2 件 (うち 1 件は動画回答) + 8 日以上前の回答 1 件 (無料状態では見えない) のサンプル
        let _ = {
            // Preview の body は複数回評価されるため、共有 in-memory コンテナへの重複挿入を防いで冪等にする
            guard (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) == 0 else { return }
            modelContext.insert(MorningAnswer(answeredDate: Calendar.current.startOfDay(for: .now), text: "家族と海を見に行く"))
            modelContext.insert(MorningAnswer(answeredDate: Calendar.current.date(byAdding: .day, value: -3, to: .now)!, text: "友人に手紙を書く", videoAssetIdentifier: "preview-video"))
            modelContext.insert(MorningAnswer(answeredDate: Calendar.current.date(byAdding: .day, value: -10, to: .now)!, text: "山に登る"))
            try! modelContext.save()
        }()
        NavigationStack {
            AnswerLogPage()
        }
        .modelContainer(container)
    }
}
