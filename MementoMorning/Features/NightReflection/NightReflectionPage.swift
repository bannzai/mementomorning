import SwiftUI
import SwiftData

/// 夜の振り返り画面。夜リマインドから開き、今朝の回答と答え合わせしてループを閉じる。
/// デザイン handoff 1j / プロトタイプ night 準拠
struct NightReflectionPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// 振り返りの対象日を決める、夜リマインドが配信された日時。日付が変わってからタップされてもこの日時の回答を振り返る
    let notificationDate: Date

    @State private var answer: MorningAnswer?
    /// 直前の記録が保存に失敗したかどうか。true の間はエラーを表示したまま画面に留まり、再タップで再試行できる
    @State private var isSaveFailed = false
    /// やれた/やれていないの記録操作へハプティクスを添えるためのトリガー。記録のたびに増える
    @State private var recordHapticTrigger = 0
    /// 動画の再生画面 (AnswerVideoPlayerPage) を開く対象の動画 (issue #80)
    @State private var replayTargetVideo: VideoAnswerReplayTarget?

    var body: some View {
        VStack(spacing: 0) {
            if let answer {
                // 回答は長さ制限のない自由入力のため、本文領域をスクロール可能にして全文を読めるようにする
                ScrollView {
                    VStack(spacing: 30) {
                        VStack(spacing: 6) {
                            // ja: 守れてますか?
                            Text("Are you keeping it?")
                                .font(.system(size: 21, weight: .light))
                                .tracking(1.68)
                                .foregroundStyle(Color.warmWhite)
                            Text(verbatim: "ARE YOU KEEPING IT?")
                                .font(.system(size: 10))
                                .tracking(2.0)
                                .foregroundStyle(Color.warmWhite.opacity(0.4))
                        }

                        Text(answer.text)
                            .font(.system(size: 25, weight: .light))
                            .tracking(0.75)
                            .lineSpacing(25 * 0.8)
                            .foregroundStyle(Color.warmWhite)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("night_reflection_answer_text")

                        // 動画で答えた朝は、今朝の自分の動画を見返す導線を添える (handoff 1j「今朝 5:52 のあなた · 動画を見返す」)
                        if let videoAssetIdentifier = answer.videoAssetIdentifier {
                            Button {
                                replayTargetVideo = VideoAnswerReplayTarget(videoAssetIdentifier: videoAssetIdentifier)
                            } label: {
                                // ja: 今朝 %@ のあなた · 動画を見返す
                                Text("You at \(answer.createdDateTime, format: .dateTime.hour().minute()) this morning · Watch the video")
                                    .font(.system(size: 11))
                                    .tracking(1.1)
                                    .foregroundStyle(Color.warmWhite.opacity(0.4))
                                    .underline()
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("night_reflection_video_replay_link")
                        }

                        if let isFulfilled = answer.isFulfilled {
                            // ja: 記録済み: %@
                            Text("Recorded: \(isFulfilled ? Text("I did") : Text("Not yet"))")
                                .font(.system(size: 11))
                                .tracking(1.1)
                                .foregroundStyle(Color.warmWhite.opacity(0.4))
                        }
                    }
                    .padding(.top, 110)
                    .padding(.horizontal, 36)
                    .frame(maxWidth: .infinity)
                }

                VStack(spacing: 14) {
                    Button {
                        record(isFulfilled: true)
                    } label: {
                        // ja: やれた
                        Text("I did")
                    }
                    .buttonStyle(PrimaryPillButtonStyle())
                    .accessibilityIdentifier("night_reflection_fulfilled_button")

                    Button {
                        record(isFulfilled: false)
                    } label: {
                        // ja: やれていない
                        Text("Not yet")
                    }
                    .buttonStyle(SecondaryPillButtonStyle())
                    .accessibilityIdentifier("night_reflection_not_fulfilled_button")

                    if isSaveFailed {
                        // ja: 保存に失敗しました。もう一度お試しください
                        Text(String(localized: "Failed to save. Please try again."))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.warmWhite.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("night_reflection_save_error")
                    }

                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            } else {
                Spacer()

                // ja: 今朝の回答はまだありません
                Text(String(localized: "No answer this morning yet."))
                    .font(.system(size: 17, weight: .light))
                    .tracking(0.68)
                    .foregroundStyle(Color.warmWhite.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    // ja: 閉じる
                    Text(String(localized: "Close"))
                }
                .buttonStyle(SecondaryPillButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.ink.ignoresSafeArea())
        // 記録の操作に軽いハプティクスを添える (handoff の Interactions & Behavior)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: recordHapticTrigger)
        .sheet(item: $replayTargetVideo) { target in
            AnswerVideoPlayerPage(videoAssetIdentifier: target.videoAssetIdentifier)
        }
        .onAppear {
            answer = fetchMorningAnswer(answeredDate: notificationDate, modelContext: modelContext)
        }
    }

    /// 夜の振り返りを記録して画面を閉じる。保存に失敗した時は記録できたと誤解させないよう閉じずにエラーを表示する
    private func record(isFulfilled: Bool) {
        recordHapticTrigger += 1
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
        let _ = {
            // Preview の body は複数回評価されるため、共有 in-memory コンテナへの重複挿入を防いで冪等にする
            guard (try? modelContext.fetchCount(FetchDescriptor<MorningAnswer>())) == 0 else { return }
            modelContext.insert(
                MorningAnswer(answeredDate: Calendar.current.startOfDay(for: .now), text: "家族と海を見に行く")
            )
            try! modelContext.save()
        }()

        NightReflectionPage(notificationDate: .now)
            .modelContainer(container)
    }
}
