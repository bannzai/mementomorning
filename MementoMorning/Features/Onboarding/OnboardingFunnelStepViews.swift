import SwiftUI

/// ペイン認識質問の選択肢 1 つ。View への入力としてだけ使う
struct OnboardingPainChoice<Answer>: Identifiable {
    /// 選択ボタンの accessibilityIdentifier。質問内で一意なため Identifiable の id として使う
    let id: String
    /// 選択肢の表示文言
    let label: Text
    /// タップした時に確定する回答
    let answer: Answer
}

/// ペイン認識質問のステップ (スヌーズ・記憶の 2 問で共通)。
/// 質問文と縦並びの選択ボタンだけを置き、タップで回答を確定して次のステップへ進む
struct OnboardingPainQuestionStepView<Answer>: View {
    /// 質問文
    let question: Text
    /// 縦並びで並べる選択肢
    let choices: [OnboardingPainChoice<Answer>]
    /// 選択肢がタップされた時に呼ばれる
    let onSelect: (Answer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            question
                .font(.system(size: 25, weight: .light))
                .tracking(1.5)
                .lineSpacing(10)
            Spacer()
            VStack(spacing: 14) {
                ForEach(choices) { choice in
                    Button {
                        onSelect(choice.answer)
                    } label: {
                        choice.label
                    }
                    .buttonStyle(SecondaryPillButtonStyle())
                    .accessibilityIdentifier(choice.id)
                }
            }
        }
        .foregroundStyle(Color.warmWhite)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 生まれ年の入力ステップ。残りの朝の回数を数えるためだけに使う値で、答えずに進むこともできる
struct OnboardingBirthYearStepView: View {
    /// ホイールで選択中の年
    @Binding var year: Int
    /// ホイールに並べる年の範囲
    let yearRange: ClosedRange<Int>
    /// 選択した年で決定した時に呼ばれる
    let onContinue: () -> Void
    /// 答えずに進むを選んだ時に呼ばれる
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ja: いつ生まれましたか？
            Text("When were you born?")
                .font(.system(size: 25, weight: .light))
                .tracking(1.5)
            // ja: あなたの朝を数えるためだけに使います。この端末の外には出ません。
            Text("Used only to count your mornings. It never leaves this device.")
                .font(.system(size: 12))
                .lineSpacing(9)
                .foregroundStyle(Color.warmWhite.opacity(0.45))
                .padding(.top, 14)
            Picker(
                // ja: 生まれ年
                String(localized: "Birth year"),
                selection: $year
            ) {
                ForEach(yearRange, id: \.self) { year in
                    // 年は桁区切り (1,990) を付けずに見せたいため、ロケール整形を通さない verbatim で描画する
                    Text(verbatim: "\(year)")
                        .tag(year)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .accessibilityIdentifier("onboarding_birth_year_picker")
            Spacer()
            VStack(spacing: 14) {
                Button {
                    onContinue()
                } label: {
                    // ja: つづける
                    Text("Continue")
                }
                .buttonStyle(PrimaryPillButtonStyle())
                .accessibilityIdentifier("onboarding_birth_year_continue")
                Button {
                    onSkip()
                } label: {
                    // ja: 答えずに進む
                    Text("Prefer not to say")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.warmWhite.opacity(0.55))
                        .underline()
                }
                .accessibilityIdentifier("onboarding_birth_year_skip")
            }
        }
        .foregroundStyle(Color.warmWhite)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 残りの朝の回数を提示するステップ (ファネルの感情のピーク)。
/// 生まれ年を答えていない・平均寿命に達している場合は、回数を出さずに普遍的な文言へ倒す
struct OnboardingMorningsResultStepView: View {
    /// 提示するパターン
    let variant: MorningsResultVariant
    /// 次のステップへ進む時に呼ばれる
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch variant {
            case .counted(let lived, let remaining):
                // ja: あなたはこれまでに、約 %lld 回の朝を迎えました。
                Text("You've already had about \(lived) mornings.")
                    .font(.system(size: 25, weight: .light))
                    .tracking(1.5)
                    .lineSpacing(12)
                // ja: 残りは、約 %lld 回。
                Text("About \(remaining) remain.")
                    .font(.system(size: 25, weight: .light))
                    .tracking(1.5)
                    .lineSpacing(12)
                    .padding(.top, 14)
                // ja: そのどれも、二度は来ません。
                Text("None of them comes back.")
                    .font(.system(size: 12))
                    .lineSpacing(9)
                    .foregroundStyle(Color.warmWhite.opacity(0.45))
                    .padding(.top, 24)
            case .unknown:
                // ja: 朝があと何回あるかは、誰にもわかりません。
                Text("No one knows how many mornings remain.")
                    .font(.system(size: 25, weight: .light))
                    .tracking(1.5)
                    .lineSpacing(12)
                // ja: だからこそ、一回ごとに意味があります。
                Text("That's exactly why each one counts.")
                    .font(.system(size: 12))
                    .lineSpacing(9)
                    .foregroundStyle(Color.warmWhite.opacity(0.45))
                    .padding(.top, 24)
            }
            Spacer()
            Button {
                onContinue()
            } label: {
                // ja: つづける
                Text("Continue")
            }
            .buttonStyle(PrimaryPillButtonStyle())
            .accessibilityIdentifier("onboarding_mornings_continue")
        }
        .foregroundStyle(Color.warmWhite)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// メメント・モリの普遍性を伝えるステップ。実践が 2000 年続いてきたものであることを示して、翌朝の問いへつなぐ
struct OnboardingMementoMoriStepView: View {
    /// 次のステップへ進む時に呼ばれる
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ja: 2000 年ものあいだ、人は「メメント・モリ」を続けてきました。死を想うと、今日が澄んで見える。
            //
            // 見出しではなく一段落の本文のため、他ステップのタイトル (25pt) より小さい 21pt にする
            // (25pt では小型端末で 1 画面に収まらない)
            Text("For two thousand years, people have kept a practice called memento mori — remember death, and the day becomes clear.")
                .font(.system(size: 21, weight: .light))
                .tracking(1.3)
                .lineSpacing(12)
            // ja: 明日の朝、ひとつの問いから始めましょう。
            Text("Tomorrow morning, you'll practice it with one question.")
                .font(.system(size: 12))
                .lineSpacing(9)
                .foregroundStyle(Color.warmWhite.opacity(0.45))
                .padding(.top, 24)
            Spacer()
            Button {
                onContinue()
            } label: {
                // ja: つづける
                Text("Continue")
            }
            .buttonStyle(PrimaryPillButtonStyle())
            .accessibilityIdentifier("onboarding_memento_continue")
        }
        .foregroundStyle(Color.warmWhite)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 整った朝の儀式を要約して見せる最終ステップ。ここから続けてペイウォールを表示する
struct OnboardingRitualSummaryStepView: View {
    /// 設定したアラームの時刻。サマリーの 1 行目に短い時刻表記で埋め込む
    let alarmTime: Date
    /// スヌーズのペイン認識質問への回答。未回答は nil
    let snoozeAnswer: OnboardingSnoozeAnswer?
    /// 記憶のペイン認識質問への回答。未回答は nil
    let memoryAnswer: OnboardingMemoryAnswer?
    /// ペイウォールへ進む時に呼ばれる
    let onBegin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ja: あなたの朝の儀式が、整いました。
            Text("Your morning ritual is ready.")
                .font(.system(size: 25, weight: .light))
                .tracking(1.5)
                .lineSpacing(10)
            VStack(alignment: .leading, spacing: 0) {
                // ja: %@ — アラームが鳴る
                summaryRow(text: Text("\(alarmTime.formatted(date: .omitted, time: .shortened)) — the alarm rings"))
                HairlineDivider()
                // ja: 自分の顔を見ながら、ひとつの問いに答える
                summaryRow(text: Text("One question, answered facing yourself"))
                HairlineDivider()
                // ja: 夜、答えと一日を答え合わせる
                summaryRow(text: Text("At night, you check the day against your answer"))
            }
            .padding(.top, 28)
            personalizedNote
                .font(.system(size: 12))
                .lineSpacing(9)
                .foregroundStyle(Color.warmWhite.opacity(0.45))
                .padding(.top, 28)
            Spacer()
            Button {
                onBegin()
            } label: {
                // ja: はじめる
                Text("Begin")
            }
            .buttonStyle(PrimaryPillButtonStyle())
            .accessibilityIdentifier("onboarding_summary_begin")
        }
        .foregroundStyle(Color.warmWhite)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// ペイン認識質問の回答に合わせた一文。優先順に最初に該当したものを 1 つだけ出す
    private var personalizedNote: Text {
        if snoozeAnswer == .almostEvery {
            // ja: もうスヌーズはいりません。アラームを止めるのは、あなたの答えだけ。
            return Text("No more snoozing. Only your answer stops the alarm.")
        }
        if memoryAnswer == .almostNone {
            // ja: 明日からの朝は、残っていきます。
            return Text("From tomorrow, your mornings will be kept.")
        }
        // ja: 明日の朝から、始まります。
        return Text("It starts tomorrow morning.")
    }

    /// サマリー 1 行。許可ステップの permissionRow と同じヘアライン区切りの行様式に合わせる
    private func summaryRow(text: Text) -> some View {
        text
            .font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
    }
}
