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

/// ペイン認識質問のステップ (5 問で共通)。
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
                // ja: あなたはこれまでに約 %lld 回の朝を迎えました
                Text("You've already had about \(lived) mornings")
                    .font(.system(size: 25, weight: .light))
                    .tracking(1.5)
                    .lineSpacing(12)
                // ja: 残りは約 %lld 回
                Text("About \(remaining) remain")
                    .font(.system(size: 25, weight: .light))
                    .tracking(1.5)
                    .lineSpacing(12)
                    .padding(.top, 14)
                // ja: そのどれも二度は来ません
                Text("None of them comes back")
                    .font(.system(size: 12))
                    .lineSpacing(9)
                    .foregroundStyle(Color.warmWhite.opacity(0.45))
                    .padding(.top, 24)
            case .unknown:
                // ja: 朝があと何回あるかは誰にもわかりません
                Text("No one knows how many mornings remain")
                    .font(.system(size: 25, weight: .light))
                    .tracking(1.5)
                    .lineSpacing(12)
                // ja: だからこそ一回ごとに意味があります
                Text("That's exactly why each one counts")
                    .font(.system(size: 12))
                    .lineSpacing(9)
                    .foregroundStyle(Color.warmWhite.opacity(0.45))
                    .padding(.top, 24)
            }
            // 問いかけと誘いは、回数を数えられた時も数えられない時も同じ様式で続けて出す
            // ja: あなたが本当に迎えたかった朝はどんな朝ですか
            Text("What kind of morning did you truly want to wake up to?")
                .font(.system(size: 12))
                .lineSpacing(9)
                .foregroundStyle(Color.warmWhite.opacity(0.45))
                .padding(.top, 14)
            // ja: 明日から気力の満ちる朝を迎えましょう
            Text("From tomorrow, wake up to mornings full of life")
                .font(.system(size: 12))
                .lineSpacing(9)
                .foregroundStyle(Color.warmWhite.opacity(0.45))
                .padding(.top, 14)
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
    /// ペイン認識質問の回答から選ばれたパーソナライズの一文 (選択ロジックは ritualSummaryNote)
    let note: RitualSummaryNote
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
                // ja: 夜は朝の回答と一日の答え合わせ
                summaryRow(text: Text("At night, check the day against your morning answer"))
            }
            .padding(.top, 28)
            noteText
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

    /// パーソナライズの一文の表示文言
    private var noteText: Text {
        switch note {
        case .answerSomeday:
            // ja: 明日の朝はその「いつか」に答えてください
            return Text("Tomorrow morning, answer that 'someday'")
        case .noMoreSnoozing:
            // ja: もうスヌーズはいりません
            //
            // アラームを止めるのはあなたの答えだけ
            return Text("No more snoozing\nOnly your answer stops the alarm")
        case .proudMornings:
            // ja: 明日から胸を張れる朝を
            return Text("From tomorrow, mornings you can be proud of")
        case .dayBeginsMorning:
            // ja: 明日からあなたの一日は朝に始まります
            return Text("From tomorrow, your day begins in the morning")
        case .firstMinutesToQuestion:
            // ja: 明日の最初の数分はスマホではなく問いのために
            return Text("Tomorrow, your first minutes go to the question, not the phone")
        case .startsTomorrow:
            // ja: 明日の朝から始まります
            return Text("It starts tomorrow morning")
        }
    }

    /// サマリー 1 行。許可ステップの permissionRow と同じヘアライン区切りの行様式に合わせる
    private func summaryRow(text: Text) -> some View {
        text
            .font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
    }
}

/// 明日の朝への約束を交わすステップ (課金転換型ファネルのコミットメント段階)。
/// 設定したアラーム時刻を埋め込んだ約束の一文を示し、リングを長押しし続けて満たすことで約束が成立する。
/// ペイン認識で自覚した課題に対して「明日は起きて答える」というコミットを自分の指で引き出してから、
/// 儀式のサマリーとペイウォールへ進む (issue #144。参考にした Wayk は署名でコミットを引き出すが、
/// 本アプリは描画キャンバスを持ち込まず、ハプティクスとリングの充填だけで静かに成立させる)
struct OnboardingPledgeStepView: View {
    /// 約束の一文に埋め込むアラーム時刻
    let alarmTime: Date
    /// 約束した朝が今日かどうか (判定は pledgeFiresToday)。
    /// 設定時刻より前にオンボーディングを終えると最初のアラームは当日に鳴るため、見出しと宣誓文の「明日」を「今日」に切り替える
    let firesToday: Bool
    /// 約束が成立して余韻を置いた後に呼ばれる
    let onPledged: () -> Void

    /// 約束の成立に必要な長押しの長さ (秒)。
    /// タップの誤操作で成立せず、かつ待たされたと感じない長さとして 1.2 秒にする。
    /// リングの充填アニメーションも同じ長さで、満ちた瞬間に約束が成立する
    static let holdDuration: TimeInterval = 1.2
    /// 約束の成立から次のステップへ進むまでの余韻 (秒)。満ちたリングとハプティクスを受け取る間
    static let pledgedPause: TimeInterval = 0.8

    /// 長押し中かどうか。リングの充填アニメーションの起点
    @State private var isHolding = false
    /// 約束が成立したかどうか。true の間はリングを満ちたままにし、指を離しても戻さない
    @State private var hasPledged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleText
                .font(.system(size: 25, weight: .light))
                .tracking(1.5)
                .lineSpacing(10)
            // 一人称の宣誓文のため、他ステップのタイトル (25pt) より小さい 21pt にする (メメント・モリの本文と同じ様式)
            pledgeText
                .font(.system(size: 21, weight: .light))
                .tracking(1.3)
                .lineSpacing(12)
                .padding(.top, 28)
                .accessibilityIdentifier("onboarding_pledge_text")
            Spacer()
            VStack(spacing: 24) {
                pledgeRing
                caption
                    .font(.system(size: 12))
                    .foregroundStyle(Color.warmWhite.opacity(0.45))
                    .accessibilityIdentifier("onboarding_pledge_caption")
            }
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Color.warmWhite)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 押し始めに柔らかく、成立時に硬く。記録操作のハプティクス (NightReflectionPage) と同じ .impact を使う
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isHolding) { _, newValue in newValue }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: hasPledged)
    }

    /// 長押しの間に夜明け色で満ちていくリング。指を離すと戻り、約束が成立すると満ちたままになる
    private var pledgeRing: some View {
        ZStack {
            Circle()
                .stroke(Color.warmWhite.opacity(0.2), lineWidth: 1)
            Circle()
                .trim(from: 0, to: isHolding || hasPledged ? 1 : 0)
                .stroke(Color.dawn, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(
                    isHolding ? .linear(duration: Self.holdDuration) : .easeOut(duration: 0.25),
                    value: isHolding
                )
            Circle()
                .fill(Color.dawn)
                .frame(width: 8, height: 8)
                .opacity(hasPledged ? 1 : (isHolding ? 0.7 : 0.35))
                .animation(.easeInOut(duration: 0.25), value: isHolding)
                .animation(.easeInOut(duration: 0.25), value: hasPledged)
        }
        .frame(width: 96, height: 96)
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: Self.holdDuration, maximumDistance: 40) {
            pledge()
        } onPressingChanged: { pressing in
            isHolding = pressing
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(captionText)
        .accessibilityAddTraits(.isButton)
        // VoiceOver では長押しの代わりにダブルタップの既定アクションで約束を成立させる
        .accessibilityAction { pledge() }
        .accessibilityIdentifier("onboarding_pledge_hold")
    }

    /// 見出し。約束した朝が今日か明日かで呼びかける相手を変える
    private var titleText: Text {
        if firesToday {
            // ja: 今日の自分に、ひとつの約束
            return Text("One promise to today's you")
        } else {
            // ja: 明日の自分に、ひとつの約束
            return Text("One promise to tomorrow's you")
        }
    }

    /// 宣誓文。最初のアラームが鳴る日 (今日 / 明日) と設定時刻を埋め込む
    private var pledgeText: Text {
        if firesToday {
            // ja: 今日の %@、私は目を覚まし、自分と向き合い、答えます。
            return Text("Today at \(alarmTime.formatted(date: .omitted, time: .shortened)), I will wake up, face myself, and answer.")
        } else {
            // ja: 明日の %@、私は目を覚まし、自分と向き合い、答えます。
            return Text("Tomorrow at \(alarmTime.formatted(date: .omitted, time: .shortened)), I will wake up, face myself, and answer.")
        }
    }

    /// リングの下の案内。約束の成立後は成立したことを伝える文言に変わる
    private var caption: some View {
        captionText
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: hasPledged)
    }

    private var captionText: Text {
        if hasPledged {
            // ja: 約束しました
            return Text("It's a promise.")
        } else {
            // ja: 長押しで約束する
            return Text("Hold to promise")
        }
    }

    /// 約束を成立させ、余韻を置いてから次のステップへ進む。成立後の再呼び出しは何もしない (二重遷移の防止)
    private func pledge() {
        guard !hasPledged else { return }
        hasPledged = true
        Task {
            try? await Task.sleep(for: .seconds(Self.pledgedPause))
            onPledged()
        }
    }
}
