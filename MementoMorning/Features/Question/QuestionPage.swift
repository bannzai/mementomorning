import SwiftUI

/// 朝の問い画面 (デザイン handoff 1a 採用案 / プロトタイプ question)。
/// アラーム停止から開き、問いに答えるまでの朝の儀式の入口になる。
///
/// この画面はデザイン反映 (issue #12) の範囲ではビジュアルシェルとして実装する:
/// - 背景のグラデーションはインカメラ映像のプレースホルダ。実映像への差し替えは動画回答 (issue #24)
/// - 録画ボタンは見た目の状態遷移 (円⇄角丸のモーフ・明滅・タイマー) のみで、実際の録画・保存はしない
/// - 回答の保存と追撃アラームの全キャンセルはアラーム連携とセットで実装する (issue #4 / #25)
struct QuestionPage: View {
    /// 録画中かどうか (ビジュアル状態のみ)
    @State private var isRecording = false
    /// 録画開始からの経過秒数 (ビジュアル状態のみ)
    @State private var recordingSeconds = 0
    /// 録画中インジケータの明滅状態
    @State private var isBlinkDimmed = false

    var body: some View {
        ZStack {
            cameraPlaceholderBackground
            scrimOverlay
            VStack(spacing: 0) {
                questionSection
                    .padding(.top, 64)
                Spacer()
                recordSection
                    .padding(.bottom, 44)
            }
            recordingIndicator
        }
        .background(Color.ink.ignoresSafeArea())
        // 録画開始/停止に軽いハプティクスを添える (handoff の Interactions & Behavior)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isRecording)
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isRecording else { return }
            recordingSeconds += 1
        }
    }

    /// インカメラ映像のプレースホルダ (issue #24 で実映像に差し替える)。
    /// radial-gradient(130% 90% at 50% 38%, #26282C → #16171A 55% → #0B0C0E)
    private var cameraPlaceholderBackground: some View {
        GeometryReader { geometry in
            RadialGradient(
                stops: [
                    .init(color: Color(red: 0x26 / 255, green: 0x28 / 255, blue: 0x2C / 255), location: 0),
                    .init(color: Color(red: 0x16 / 255, green: 0x17 / 255, blue: 0x1A / 255), location: 0.55),
                    .init(color: .ink, location: 1),
                ],
                center: UnitPoint(x: 0.5, y: 0.38),
                startRadius: 0,
                endRadius: geometry.size.width * 1.3
            )
        }
        .ignoresSafeArea()
    }

    /// 明るい寝室でも問いが読めるようにする上下のスクリム
    private var scrimOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .ink.opacity(0.72), location: 0),
                .init(color: .ink.opacity(0.25), location: 0.26),
                .init(color: .ink.opacity(0), location: 0.42),
                .init(color: .ink.opacity(0), location: 0.62),
                .init(color: .ink.opacity(0.78), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// 問いの本文と英語サブラベル
    private var questionSection: some View {
        VStack(spacing: 14) {
            // ja: 今日死ぬとしたら、何をやりたいか
            Text("If today were your last day, what would you want to do?")
                .font(.system(size: 27, weight: .light))
                .tracking(1.35)
                .lineSpacing(27 * 0.65)
                .foregroundStyle(Color.warmWhite)
                .shadow(color: .ink.opacity(0.6), radius: 12, y: 1)
            // 日本語等のロケールでのみ添える英訳。英語ロケールでは本文と重複するため出さない
            if String(localized: "If today were your last day, what would you want to do?") != "If today were your last day, what would you want to do?" {
                Text(verbatim: "If today were your last day,\nwhat would you want to do?")
                    .font(.system(size: 11))
                    .tracking(0.66)
                    .lineSpacing(11 * 0.7)
                    .foregroundStyle(Color.warmWhite.opacity(0.5))
                    .shadow(color: .ink.opacity(0.6), radius: 6, y: 1)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 36)
    }

    /// 録画ボタンとラベル・代替入力リンク
    private var recordSection: some View {
        VStack(spacing: 18) {
            Button {
                if isRecording {
                    isRecording = false
                } else {
                    recordingSeconds = 0
                    isRecording = true
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.warmWhite.opacity(0.85), lineWidth: 1.5)
                        .frame(width: 84, height: 84)
                    // 録画中は内側が 34pt の角丸四角に 0.35s で変形する (SNS 的な赤 REC は使わない)
                    RoundedRectangle(cornerRadius: isRecording ? 8 : 32)
                        .fill(Color.warmWhite)
                        .frame(
                            width: isRecording ? 34 : 64,
                            height: isRecording ? 34 : 64
                        )
                        .animation(.easeInOut(duration: 0.35), value: isRecording)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isRecording
                    // ja: 止める
                    ? Text("Stop")
                    // ja: 話して、答える
                    : Text("Speak your answer")
            )
            .accessibilityIdentifier("question_record_button")

            // 状態の切り替えでこの領域の高さが変わると録画ボタンの位置が跳ねるため、
            // 両状態を重ねて不透明度で切り替え、高さを常に維持する (遷移はフェードのみ)
            ZStack {
                VStack(spacing: 18) {
                    VStack(spacing: 4) {
                        // ja: 話して、答える
                        Text("Speak your answer")
                            .font(.system(size: 13))
                            .tracking(1.3)
                            .foregroundStyle(Color.warmWhite.opacity(0.85))
                        Text(verbatim: "SPEAK YOUR ANSWER")
                            .font(.system(size: 10))
                            .tracking(0.8)
                            .foregroundStyle(Color.warmWhite.opacity(0.4))
                    }
                    // ja: キーボードで答える
                    Text("Answer with the keyboard")
                        .font(.system(size: 12))
                        .tracking(0.96)
                        .foregroundStyle(Color.warmWhite.opacity(0.45))
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.warmWhite.opacity(0.2))
                                .frame(height: 1)
                                .offset(y: 2)
                        }
                        // タップでの文字起こし確認 (キーボード入力) への遷移は issue #4 / #25 で配線する
                }
                .opacity(isRecording ? 0 : 1)
                // ja: 止めると、アラームも止まります
                Text("Stop, and the alarm stops too.")
                    .font(.system(size: 12))
                    .tracking(1.44)
                    .foregroundStyle(Color.warmWhite.opacity(0.55))
                    .opacity(isRecording ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.35), value: isRecording)
        }
    }

    /// 録画中の右上インジケータ (ゆっくり明滅する点 + mono タイマー)
    @ViewBuilder
    private var recordingIndicator: some View {
        if isRecording {
            VStack {
                HStack(spacing: 8) {
                    Spacer()
                    Circle()
                        .fill(Color.warmWhite)
                        .frame(width: 6, height: 6)
                        .opacity(isBlinkDimmed ? 0.25 : 0.8)
                        .onAppear {
                            // 1.6s 周期のゆっくりした明滅 (opacity 0.25 ⇄ 0.8)
                            withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                                isBlinkDimmed = true
                            }
                        }
                        .onDisappear {
                            isBlinkDimmed = false
                        }
                    Text(verbatim: String(format: "%d:%02d", recordingSeconds / 60, recordingSeconds % 60))
                        .font(.system(size: 13, design: .monospaced))
                        .tracking(1.3)
                        .foregroundStyle(Color.warmWhite.opacity(0.75))
                }
                .padding(.top, 24)
                .padding(.trailing, 28)
                Spacer()
            }
        }
    }
}

struct QuestionPage_Previews: PreviewProvider {
    static var previews: some View {
        QuestionPage()
    }
}
