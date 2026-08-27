import AlarmKit
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

extension String {
    /// オンボーディング完了済みかどうかを保存する UserDefaults キー。
    /// RootView が起動時の画面分岐 (オンボーディング / ホーム) に使う
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}

/// 許可ステップで設定アプリへの誘導を表示すべきかどうか。
/// どちらかの許可が明示的に拒否されている場合だけ誘導する
/// (未決定はシステムダイアログでリクエストできるため、設定アプリへ誘導する必要がない)
func needsPermissionSettingsGuidance(
    alarmAuthorizationState: AlarmManager.AuthorizationState,
    notificationAuthorizationStatus: UNAuthorizationStatus
) -> Bool {
    alarmAuthorizationState == .denied || notificationAuthorizationStatus == .denied
}

/// 初回起動時のオンボーディング。
/// コンセプト提示 → ペイン認識の 5 問 → 生まれ年 → 残りの朝 → メメント・モリ → アラーム・通知の許可 →
/// 回答の練習 → 最初のアラーム設定 → 儀式のサマリー、の 13 ステップを 1 画面内のフェードで進め、
/// 最後にペイウォールを fullScreenCover で表示して完了する (課金転換型ファネルへの再設計。issue #140)
/// (デザイン: design_handoff_memento_morning の 1m「夜明けの一枚目」。画面遷移はフェードのみ)。
/// 練習ステップは、朝の初回がぶっつけ本番の録画にならないよう事前に一度録画を試すチュートリアル (issue #44)。
/// カメラ・マイク・写真ライブラリ・音声認識の権限も、使い道の説明を見せてからここでまとめてリクエストする
struct OnboardingPage: View {
    /// オンボーディングの進行ステップ
    private enum Step {
        case concept
        case painWake
        case painSatisfaction
        case firstMinutes
        case dayBegin
        case undoneGoal
        case birthYear
        case morningsResult
        case mementoMori
        case permission
        case practice
        case alarmSetting
        case ritualSummary
    }

    /// 練習ステップ内の進行状態
    private enum PracticePhase {
        /// 説明と権限の使い道の提示 (権限リクエストは「一度やってみる」のタップまで実行しない)
        case introduction
        /// インカメラのプレビューを表示して録画を試している
        case recording
        /// 録画を止めて練習を終えた
        case completed
        /// 動画回答を使えない (権限拒否・カメラ非搭載環境)。朝はテキスト入力になることを案内する
        case unavailable
    }

    /// モデルコンテキスト
    @Environment(\.modelContext) private var modelContext
    /// アプリのライフサイクル状態。設定アプリから戻ってきた時に許可状態を再読込するために監視する
    @Environment(\.scenePhase) private var scenePhase
    /// 設定アプリを開くための URL オープナー
    @Environment(\.openURL) private var openURL
    /// 保存済みのアラーム設定。単一レコード運用のため先頭 1 件のみ使う
    /// (デバッグメニューのリセット等でオンボーディングを再走した場合は既存レコードを更新する)
    @Query private var alarmSettings: [AlarmSetting]
    /// オンボーディング完了フラグ。true にすると RootView がホームへ切り替える
    @AppStorage(.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = false
    /// 入力された生まれ年 (0 = 未回答)。残りの朝の回数の計算に使う
    @AppStorage(.onboardingBirthYear) private var onboardingBirthYear: Int = 0
    /// 起床のペイン認識質問への回答 (OnboardingWakeAnswer の rawValue。未回答は空文字)
    @AppStorage(.onboardingWakeAnswer) private var onboardingWakeAnswer: String = ""
    /// 朝の迎え方への満足度の質問への回答 (OnboardingMorningSatisfactionAnswer の rawValue。未回答は空文字)
    @AppStorage(.onboardingMorningSatisfactionAnswer) private var onboardingMorningSatisfactionAnswer: String = ""
    /// 目覚めてすぐの過ごし方の質問への回答 (OnboardingFirstMinutesAnswer の rawValue。未回答は空文字)
    @AppStorage(.onboardingFirstMinutesAnswer) private var onboardingFirstMinutesAnswer: String = ""
    /// 一日が本当に始まる時間帯の質問への回答 (OnboardingDayBeginAnswer の rawValue。未回答は空文字)
    @AppStorage(.onboardingDayBeginAnswer) private var onboardingDayBeginAnswer: String = ""
    /// 「いつかやる」と言い続けていることの質問への回答 (OnboardingUndoneGoalAnswer の rawValue。未回答は空文字)
    @AppStorage(.onboardingUndoneGoalAnswer) private var onboardingUndoneGoalAnswer: String = ""

    /// 現在のステップ
    @State private var step: Step = .concept
    /// 生まれ年ステップのホイールで選択中の年 (西暦)。
    /// 初期値の 39 年前は US の年齢中央値 (約 39 歳。US Census Bureau ACS 2023) に合わせたもので、
    /// 主戦場の US ユーザーがホイールをほとんど回さずに決定できる位置から始める
    @State private var birthYear: Int = gregorianYear(date: .now) - 39
    /// ペイウォールを表示中かどうか。閉じた時点でオンボーディングを完了する
    @State private var isPaywallPresented: Bool = false
    /// AlarmKit の認可状態
    @State private var alarmAuthorizationState: AlarmManager.AuthorizationState = .notDetermined
    /// 通知の認可状態
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    /// 許可リクエストを一度でも実行したかどうか。実行後に「つづける」導線を出すために使う
    @State private var hasRequestedPermissions: Bool = false
    /// 許可リクエストの実行中かどうか。連打によるダイアログの多重リクエストを防ぐ
    @State private var isRequestingPermissions: Bool = false
    /// DatePicker 入力用。保存時に hour/minute へ分解する。
    /// 7:00 は日本の平均起床時刻帯 (総務省 社会生活基本調査で 6〜7 時台) に合わせた初期値。保存前にユーザーが変更できる
    @State private var time: Date = Calendar.autoupdatingCurrent.date(bySettingHour: 7, minute: 0, second: 0, of: .now) ?? .now
    /// 保存に失敗した場合のエラー。nil 以外で画面内に表示する
    @State private var saveError: String?
    /// 保存処理 (再スケジュール完了待ち) の実行中かどうか。
    /// true の間はボタンを無効化し、連打による複数 Task の並行起動を防ぐ
    @State private var isSaving: Bool = false
    /// 練習用のインカメラ録画セッション (朝の本番と同じ VideoAnswerCamera を使う)
    @State private var practiceCamera = VideoAnswerCamera()
    /// 練習ステップ内の進行状態
    @State private var practicePhase: PracticePhase = .introduction
    /// 練習の権限リクエストの実行中かどうか。連打によるダイアログの多重リクエストを防ぐ
    @State private var isRequestingPracticePermissions = false

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            dawnHorizon
            switch step {
            case .concept:
                conceptStep.transition(.opacity)
            case .painWake:
                painWakeStep.transition(.opacity)
            case .painSatisfaction:
                painSatisfactionStep.transition(.opacity)
            case .firstMinutes:
                firstMinutesStep.transition(.opacity)
            case .dayBegin:
                dayBeginStep.transition(.opacity)
            case .undoneGoal:
                undoneGoalStep.transition(.opacity)
            case .birthYear:
                birthYearStep.transition(.opacity)
            case .morningsResult:
                morningsResultStep.transition(.opacity)
            case .mementoMori:
                mementoMoriStep.transition(.opacity)
            case .permission:
                permissionStep.transition(.opacity)
            case .practice:
                practiceStep.transition(.opacity)
            case .alarmSetting:
                alarmSettingStep.transition(.opacity)
            case .ritualSummary:
                ritualSummaryStep.transition(.opacity)
            }
            funnelProgressLine
        }
        // ダークテーマの指定は RootView が両画面の親でまとめて当てる
        .fullScreenCover(isPresented: $isPaywallPresented, onDismiss: {
            // 購入・復元・「今はしない」のいずれで閉じてもオンボーディングを完了する (無料層があるため非購入でも進める)
            hasCompletedOnboarding = true
        }) {
            PaywallPage(remainingMorningsCount: remainingMorningsCount)
        }
        .onChange(of: scenePhase) { _, newValue in
            // 設定アプリで許可を変更して戻ってきた場合に表示へ反映する
            guard newValue == .active else { return }
            Task { await refreshPermissionStates() }
        }
    }

    /// 現在の年 (西暦)。生まれ年ホイールの上限と、残りの朝の回数の計算に使う
    private var currentYear: Int {
        gregorianYear(date: .now)
    }

    /// ペイウォールのタイトル上に出す残りの朝の回数。生まれ年から数えられない場合は文脈行を出さない (nil)
    private var remainingMorningsCount: Int? {
        switch morningsResultVariant(birthYear: onboardingBirthYear, currentYear: currentYear) {
        case .counted(_, let remaining):
            return remaining
        case .unknown:
            return nil
        }
    }

    /// 質問セクション (ペイン認識 5 問 → 生まれ年 → 残りの朝 → メメント・モリ) の進捗 (0〜1)。
    /// セクション外のステップでは nil にしてプログレス表示を出さない
    private var funnelProgressRatio: CGFloat? {
        switch step {
        case .painWake:
            return 1.0 / 8.0
        case .painSatisfaction:
            return 2.0 / 8.0
        case .firstMinutes:
            return 3.0 / 8.0
        case .dayBegin:
            return 4.0 / 8.0
        case .undoneGoal:
            return 5.0 / 8.0
        case .birthYear:
            return 6.0 / 8.0
        case .morningsResult:
            return 7.0 / 8.0
        case .mementoMori:
            return 8.0 / 8.0
        case .concept, .permission, .practice, .alarmSetting, .ritualSummary:
            return nil
        }
    }

    /// 質問セクションの進捗を示す、セーフエリア直下の 1pt のライン
    @ViewBuilder
    private var funnelProgressLine: some View {
        if let ratio = funnelProgressRatio {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Color.dawn.opacity(0.55))
                        .frame(width: proxy.size.width * ratio)
                }
                .frame(height: 1)
                Spacer()
            }
        }
    }

    /// 画面下部の夜明けグラデーションと地平線。全ステップ共通の背景装飾
    private var dawnHorizon: some View {
        VStack(spacing: 0) {
            Spacer()
            LinearGradient(
                stops: [
                    .init(color: Color.dawn.opacity(0), location: 0),
                    .init(color: Color.dawn.opacity(0.14), location: 0.7),
                    .init(color: Color.dawn.opacity(0.22), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
        }
        .overlay(alignment: .bottom) {
            // 地平線。中央が最も明るい 1pt のライン
            LinearGradient(
                colors: [Color.dawn.opacity(0), Color.dawn.opacity(0.55), Color.dawn.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            .padding(.bottom, 216)
        }
        .ignoresSafeArea()
    }

    /// ステップ 1: コンセプト提示
    private var conceptStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            // ja: 死を想ってから、
            //
            // 朝を始める。
            Text("Remember death.\nThen begin your morning.")
                .font(.system(size: 29, weight: .light))
                .tracking(1.7)
                .lineSpacing(14)
            // ja: 毎朝ひとつの問いに答えて、アラームを止める。
            //
            // 答えは、あなたの人生のジャーナルになる。
            Text("Answer one question each morning to stop the alarm.\nYour answers become the journal of your life.")
                .font(.system(size: 12, weight: .light))
                .lineSpacing(9)
                .foregroundStyle(Color.warmWhite.opacity(0.45))
                .padding(.top, 14)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.6)) { step = .painWake }
            } label: {
                // ja: はじめる
                Text("Begin")
            }
            .buttonStyle(PrimaryPillButtonStyle())
            .accessibilityIdentifier("onboarding_begin")
        }
        .foregroundStyle(Color.warmWhite)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// ステップ 2: ペイン認識質問 1 (起床)。回答は儀式サマリーの一文の出し分けに使う
    private var painWakeStep: some View {
        OnboardingPainQuestionStepView<OnboardingWakeAnswer>(
            // ja: 朝は一度のアラームで起きられますか？
            question: Text("Can you wake up with a single alarm?"),
            choices: [
                // ja: ほとんど起きられない
                .init(id: "onboarding_pain_wake_almost_never", label: Text("Almost never"), answer: .almostNever),
                // ja: ときどき
                .init(id: "onboarding_pain_wake_sometimes", label: Text("Sometimes"), answer: .sometimes),
                // ja: だいたい起きられる
                .init(id: "onboarding_pain_wake_almost_always", label: Text("Almost always"), answer: .almostAlways),
            ],
            onSelect: { answer in
                onboardingWakeAnswer = answer.rawValue
                withAnimation(.easeInOut(duration: 0.6)) { step = .painSatisfaction }
            }
        )
    }

    /// ステップ 3: ペイン認識質問 2 (朝の迎え方への満足)。回答は儀式サマリーの一文の出し分けに使う
    private var painSatisfactionStep: some View {
        OnboardingPainQuestionStepView<OnboardingMorningSatisfactionAnswer>(
            // ja: いまの朝の迎え方に満足していますか？
            question: Text("Are you happy with how your mornings begin?"),
            choices: [
                // ja: 満足していない
                .init(id: "onboarding_pain_satisfaction_not_really", label: Text("No, not really"), answer: .notReally),
                // ja: どちらとも言えない
                .init(id: "onboarding_pain_satisfaction_somewhat", label: Text("Somewhat"), answer: .somewhat),
                // ja: おおむね満足している
                .init(id: "onboarding_pain_satisfaction_mostly", label: Text("Mostly"), answer: .mostly),
            ],
            onSelect: { answer in
                onboardingMorningSatisfactionAnswer = answer.rawValue
                withAnimation(.easeInOut(duration: 0.6)) { step = .firstMinutes }
            }
        )
    }

    /// ステップ 4: ペイン認識質問 3 (目覚めてすぐの過ごし方)。回答は儀式サマリーの一文の出し分けに使う
    private var firstMinutesStep: some View {
        OnboardingPainQuestionStepView<OnboardingFirstMinutesAnswer>(
            // ja: 起きてすぐの時間をどう過ごしていますか？
            question: Text("What do your first minutes of the day look like?"),
            choices: [
                // ja: スマホを眺めている
                .init(id: "onboarding_first_minutes_scrolling", label: Text("Scrolling my phone"), answer: .scrolling),
                // ja: あわただしく一日が始まる
                .init(id: "onboarding_first_minutes_rushing", label: Text("Rushing to start the day"), answer: .rushing),
                // ja: 朝の習慣がある
                .init(id: "onboarding_first_minutes_ritual", label: Text("I have a morning ritual"), answer: .ritual),
            ],
            onSelect: { answer in
                onboardingFirstMinutesAnswer = answer.rawValue
                withAnimation(.easeInOut(duration: 0.6)) { step = .dayBegin }
            }
        )
    }

    /// ステップ 5: ペイン認識質問 4 (一日が本当に始まる時間帯)。回答は儀式サマリーの一文の出し分けに使う
    private var dayBeginStep: some View {
        OnboardingPainQuestionStepView<OnboardingDayBeginAnswer>(
            // ja: あなたの一日が本当に始まるのはいつですか？
            question: Text("When does your day really begin?"),
            choices: [
                // ja: 朝から
                .init(id: "onboarding_day_begin_morning", label: Text("In the morning"), answer: .morning),
                // ja: 昼ごろ
                .init(id: "onboarding_day_begin_noon", label: Text("Around noon"), answer: .noon),
                // ja: 夕方になってようやく
                .init(id: "onboarding_day_begin_evening", label: Text("By evening, finally"), answer: .evening),
            ],
            onSelect: { answer in
                onboardingDayBeginAnswer = answer.rawValue
                withAnimation(.easeInOut(duration: 0.6)) { step = .undoneGoal }
            }
        )
    }

    /// ステップ 6: ペイン認識質問 5 (手つかずの「いつか」)。回答は儀式サマリーの一文の出し分けに使う
    private var undoneGoalStep: some View {
        OnboardingPainQuestionStepView<OnboardingUndoneGoalAnswer>(
            // ja: 「いつかやる」と言い続けていることはありますか？
            question: Text("Is there something you keep telling yourself you'll do?"),
            choices: [
                // ja: あるが手つかずのまま
                .init(id: "onboarding_undone_goal_yes", label: Text("Yes, and it stays undone"), answer: .undone),
                // ja: いくつかある
                .init(id: "onboarding_undone_goal_a_few", label: Text("A few things"), answer: .aFew),
                // ja: 特にない
                .init(id: "onboarding_undone_goal_none", label: Text("Not really"), answer: .notReally),
            ],
            onSelect: { answer in
                onboardingUndoneGoalAnswer = answer.rawValue
                withAnimation(.easeInOut(duration: 0.6)) { step = .birthYear }
            }
        )
    }

    /// ステップ 7: 生まれ年の入力 (スキップ可)。保存先は端末内のみ (ADR 0001)
    private var birthYearStep: some View {
        OnboardingBirthYearStepView(
            year: $birthYear,
            // 下限の 1900 年は、存命のユーザーの生まれ年として十分に古く、ホイールの候補を無用に増やさない値
            yearRange: 1900...currentYear,
            onContinue: {
                onboardingBirthYear = birthYear
                withAnimation(.easeInOut(duration: 0.6)) { step = .morningsResult }
            },
            onSkip: {
                // オンボーディングを再走した時に前回の回答が残らないよう、未回答を表す 0 へ明示的に戻す
                onboardingBirthYear = 0
                withAnimation(.easeInOut(duration: 0.6)) { step = .morningsResult }
            }
        )
    }

    /// ステップ 8: 残りの朝の回数の提示
    private var morningsResultStep: some View {
        OnboardingMorningsResultStepView(
            variant: morningsResultVariant(birthYear: onboardingBirthYear, currentYear: currentYear),
            onContinue: {
                withAnimation(.easeInOut(duration: 0.6)) { step = .mementoMori }
            }
        )
    }

    /// ステップ 9: メメント・モリの普遍性の提示
    private var mementoMoriStep: some View {
        OnboardingMementoMoriStepView(
            onContinue: {
                withAnimation(.easeInOut(duration: 0.6)) { step = .permission }
            }
        )
    }

    /// ステップ 13: 儀式のサマリー。「はじめる」でペイウォールへ進む
    private var ritualSummaryStep: some View {
        OnboardingRitualSummaryStepView(
            alarmTime: time,
            note: ritualSummaryNote(
                undoneGoal: OnboardingUndoneGoalAnswer(rawValue: onboardingUndoneGoalAnswer),
                wake: OnboardingWakeAnswer(rawValue: onboardingWakeAnswer),
                satisfaction: OnboardingMorningSatisfactionAnswer(rawValue: onboardingMorningSatisfactionAnswer),
                dayBegin: OnboardingDayBeginAnswer(rawValue: onboardingDayBeginAnswer),
                firstMinutes: OnboardingFirstMinutesAnswer(rawValue: onboardingFirstMinutesAnswer)
            ),
            onBegin: {
                isPaywallPresented = true
            }
        )
    }

    /// ステップ 10: アラーム・通知の許可リクエスト
    private var permissionStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ja: アラームと通知の許可
            Text("Alarm & Notifications")
                .font(.system(size: 25, weight: .light))
                .tracking(1.5)
            VStack(alignment: .leading, spacing: 0) {
                // ja: アラーム
                // ja: 設定した時刻に、サイレントモードでも鳴ります
                permissionRow(
                    title: Text("Alarm"),
                    detail: Text("Rings at your time, even in silent mode."),
                    isGranted: alarmAuthorizationState == .authorized
                )
                HairlineDivider()
                // ja: 夜のリマインド
                // ja: 今朝の回答と答え合わせしましょう
                permissionRow(
                    title: Text("Night reminder"),
                    detail: Text("Check tonight against this morning's answer."),
                    isGranted: notificationAuthorizationStatus == .authorized
                )
            }
            .padding(.top, 28)
            if needsPermissionSettingsGuidance(
                alarmAuthorizationState: alarmAuthorizationState,
                notificationAuthorizationStatus: notificationAuthorizationStatus
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    // ja: 許可は設定アプリから変更できます
                    Text("You can change permissions in the Settings app.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.warmWhite.opacity(0.45))
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        // ja: 設定を開く
                        Text("Open Settings")
                    }
                    .buttonStyle(SecondaryPillButtonStyle())
                    .accessibilityIdentifier("onboarding_open_settings")
                }
                .padding(.top, 28)
            }
            Spacer()
            VStack(spacing: 14) {
                Button {
                    Task { await requestPermissions() }
                } label: {
                    // ja: 許可する
                    Text("Allow")
                }
                .buttonStyle(PrimaryPillButtonStyle())
                .disabled(isRequestingPermissions)
                .accessibilityIdentifier("onboarding_allow_permissions")
                if hasRequestedPermissions {
                    Button {
                        withAnimation(.easeInOut(duration: 0.6)) { step = .practice }
                    } label: {
                        // ja: つづける
                        Text("Continue")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.warmWhite.opacity(0.55))
                            .underline()
                    }
                    .accessibilityIdentifier("onboarding_continue")
                }
            }
        }
        .foregroundStyle(Color.warmWhite)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            await refreshPermissionStates()
        }
    }

    /// ステップ 11: 回答の練習 (インカメラ録画のチュートリアル)。
    /// 権限の使い道を説明してから「一度やってみる」のタップでまとめてリクエストし、揃ったら録画を一度試す。
    /// 練習の録画は回答ではないため保存しない。権限拒否・カメラ非搭載環境では朝はテキスト入力になることを案内して先へ進める
    @ViewBuilder
    private var practiceStep: some View {
        switch practicePhase {
        case .introduction:
            practiceIntroduction
        case .recording:
            practiceRecording
        case .completed:
            practiceCompleted
        case .unavailable:
            practiceUnavailable
        }
    }

    /// 練習の説明と権限の使い道の提示。ダイアログは「一度やってみる」のタップまで出さない
    private var practiceIntroduction: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ja: 回答の練習
            Text("Practice your answer")
                .font(.system(size: 25, weight: .light))
                .tracking(1.5)
            // ja: 毎朝、インカメラで答えを録画してアラームを止めます。
            //
            // 最初の朝が来る前に、一度だけ試しておきましょう。
            Text("Each morning, you record your answer with the front camera to stop the alarm.\nTry it once, before your first morning.")
                .font(.system(size: 12))
                .lineSpacing(9)
                .foregroundStyle(Color.warmWhite.opacity(0.45))
                .padding(.top, 14)
            VStack(alignment: .leading, spacing: 0) {
                // リクエスト前の使い道の説明のため、許可済みバッジ (isGranted) は常に出さない
                // ja: カメラとマイク
                // ja: 回答の動画を録画します
                permissionRow(
                    title: Text("Camera & microphone"),
                    detail: Text("Records your video answer."),
                    isGranted: false
                )
                HairlineDivider()
                // ja: 写真ライブラリ
                // ja: 動画を写真アプリのアルバム「Memento Morning」に保存します
                permissionRow(
                    title: Text("Photo library"),
                    detail: Text("Saves your videos to the 'Memento Morning' album in Photos."),
                    isGranted: false
                )
                HairlineDivider()
                // ja: 音声認識
                // ja: 動画の音声を、端末の中だけで文字にします
                permissionRow(
                    title: Text("Speech recognition"),
                    detail: Text("Turns your voice into text, on this device."),
                    isGranted: false
                )
            }
            .padding(.top, 28)
            Spacer()
            VStack(spacing: 14) {
                Button {
                    Task { await startPractice() }
                } label: {
                    // ja: 一度やってみる
                    Text("Try it once")
                }
                .buttonStyle(PrimaryPillButtonStyle())
                .disabled(isRequestingPracticePermissions)
                .accessibilityIdentifier("onboarding_practice_start")
                Button {
                    withAnimation(.easeInOut(duration: 0.6)) { step = .alarmSetting }
                } label: {
                    // ja: あとでやる
                    Text("Later")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.warmWhite.opacity(0.55))
                        .underline()
                }
                .accessibilityIdentifier("onboarding_practice_skip")
            }
        }
        .foregroundStyle(Color.warmWhite)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 練習の録画。朝の本番 (MorningQuestionPage) と同じく問いをプレビューへオーバーレイし、録画停止で練習を終える
    private var practiceRecording: some View {
        ZStack {
            if practiceCamera.isSessionRunning {
                CameraPreviewView(session: practiceCamera.session)
                    .ignoresSafeArea()
            }
            // プレビュー (顔) の上でも問いと操作が読めるよう、上下に墨のスクリムを敷く (MorningQuestionPage と同じ演出)
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.ink.opacity(0.75), Color.ink.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 280)
                Spacer()
                LinearGradient(
                    colors: [Color.ink.opacity(0), Color.ink.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // ja: 今日死ぬとしたら何をやりたいですか？
                Text(String(localized: "If today were your last day, what would you want to do?"))
                    .font(.system(size: 27, weight: .light))
                    .lineSpacing(10)
                    .multilineTextAlignment(.center)
                    .padding(.top, 110)
                    .padding(.horizontal, 32)
                // ja: 練習です。動画は保存されません
                Text("This is practice. The video won't be saved.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.warmWhite.opacity(0.55))
                    .padding(.top, 14)
                Spacer()
                practiceRecordingControls
                    .padding(.bottom, 32)
            }
        }
        .foregroundStyle(Color.warmWhite)
        .onDisappear {
            practiceCamera.stop()
        }
    }

    /// 練習用の録画ボタンと録画中のインジケーター (朝の問いと同じ VideoAnswerRecordingControls)。
    /// 練習でも 10 秒の上限で自動停止するため、本番と同じタイマーとリングで予告する
    private var practiceRecordingControls: some View {
        VideoAnswerRecordingControls(
            camera: practiceCamera,
            isDisabled: false,
            // ja: 録画を止める
            stopAccessibilityLabel: Text("Stop recording"),
            accessibilityIdentifierPrefix: "onboarding_practice"
        )
    }

    /// 練習の完了。朝の本番の動きを一言添えて次のステップへ進める
    private var practiceCompleted: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ja: これで、朝の準備ができました
            Text("You're ready for the morning.")
                .font(.system(size: 25, weight: .light))
                .tracking(1.5)
            // ja: 朝は、録画を止めるとアラームが止まります
            Text("In the morning, stopping the recording stops the alarm.")
                .font(.system(size: 12))
                .lineSpacing(9)
                .foregroundStyle(Color.warmWhite.opacity(0.45))
                .padding(.top, 14)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.6)) { step = .alarmSetting }
            } label: {
                // ja: つづける
                Text("Continue")
            }
            .buttonStyle(PrimaryPillButtonStyle())
            .accessibilityIdentifier("onboarding_practice_continue")
        }
        .foregroundStyle(Color.warmWhite)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 動画回答を使えない場合の案内 (権限拒否・カメラ非搭載環境)。朝はテキスト入力へフォールバックする旨を伝えて先へ進める
    private var practiceUnavailable: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ja: 回答の練習
            Text("Practice your answer")
                .font(.system(size: 25, weight: .light))
                .tracking(1.5)
            // ja: カメラを使えないため、テキストで答えます
            Text("The camera isn't available, so answer in text.")
                .font(.system(size: 12))
                .lineSpacing(9)
                .foregroundStyle(Color.warmWhite.opacity(0.45))
                .padding(.top, 14)
            // ja: 許可は設定アプリから変更できます
            Text("You can change permissions in the Settings app.")
                .font(.system(size: 12))
                .foregroundStyle(Color.warmWhite.opacity(0.45))
                .padding(.top, 14)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.6)) { step = .alarmSetting }
            } label: {
                // ja: つづける
                Text("Continue")
            }
            .buttonStyle(PrimaryPillButtonStyle())
            .accessibilityIdentifier("onboarding_practice_continue")
        }
        .foregroundStyle(Color.warmWhite)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 練習の開始: 動画回答の権限 (カメラ → マイク → 写真ライブラリ) と音声認識をまとめてリクエストし、使えるなら録画練習へ進む。
    /// 音声認識は動画回答の必須権限ではない (拒否しても録画・保存はできる。VideoAnswerTranscriber 参照) ため、
    /// 判定には使わず、初回の文字起こし時に不意のダイアログが出ないようここで確定だけさせる
    private func startPractice() async {
        guard !isRequestingPracticePermissions else { return }
        isRequestingPracticePermissions = true
        defer { isRequestingPracticePermissions = false }
        let isPermitted = await requestVideoAnswerPermissions()
        _ = await requestSpeechRecognitionAuthorization()
        guard isPermitted else {
            withAnimation(.easeInOut(duration: 0.6)) { practicePhase = .unavailable }
            return
        }
        practiceCamera.onFinished = { fileURL in
            // 練習の録画は回答ではないため、写真ライブラリへ保存せず捨てる
            try? FileManager.default.removeItem(at: fileURL)
            practiceCamera.stop()
            withAnimation(.easeInOut(duration: 0.6)) { practicePhase = .completed }
        }
        practiceCamera.onRecordingFailed = { _ in
            // 練習の目的 (権限の確定と操作の体験) は録画の成否に依らず果たされているため、失敗でも完了へ進める
            practiceCamera.stop()
            withAnimation(.easeInOut(duration: 0.6)) { practicePhase = .completed }
        }
        practiceCamera.onUnavailable = {
            withAnimation(.easeInOut(duration: 0.6)) { practicePhase = .unavailable }
        }
        withAnimation(.easeInOut(duration: 0.6)) { practicePhase = .recording }
        practiceCamera.start()
    }

    /// ステップ 12: 最初のアラーム設定
    private var alarmSettingStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ja: 最初のアラーム
            Text("Your first alarm")
                .font(.system(size: 25, weight: .light))
                .tracking(1.5)
            // ja: 答えるまで、アラームは鳴り続けます
            Text("The alarm keeps returning until you answer.")
                .font(.system(size: 12))
                .foregroundStyle(Color.warmWhite.opacity(0.45))
                .padding(.top, 14)
            DatePicker(
                // ja: 時刻
                String(localized: "Time"),
                selection: $time,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            if let saveError {
                // エラーメッセージはそのまま表示する (加工しない)。低彩度の世界観に合わせて赤は使わない。
                // 全アラームの登録に失敗すると同種のエラーが件数分 (最大 30 件) 改行結合されるため、
                // 行数を制限して下の「設定を開く」ボタンが画面外へ押し出されないようにする
                Text(saveError)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dawn)
                    .lineLimit(4)
                    .padding(.top, 14)
                if alarmAuthorizationState == .denied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        // ja: 設定を開く
                        Text("Open Settings")
                    }
                    .buttonStyle(SecondaryPillButtonStyle())
                    .accessibilityIdentifier("onboarding_alarm_open_settings")
                    .padding(.top, 14)
                }
            }
            Spacer()
            Button {
                save()
            } label: {
                // ja: アラームをセットする
                Text("Set alarm")
            }
            .buttonStyle(PrimaryPillButtonStyle())
            .disabled(isSaving)
            .accessibilityIdentifier("onboarding_set_alarm")
        }
        .foregroundStyle(Color.warmWhite)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            // 既にアラーム設定がある場合 (デバッグメニューのリセット等でオンボーディングを再走した場合) は、
            // 既定値 7:00 で既存の設定時刻を上書きしないよう DatePicker の初期値を復元する
            guard let alarmSetting = alarmSettings.first else { return }
            var components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: .now)
            components.hour = alarmSetting.hour
            components.minute = alarmSetting.minute
            if let date = Calendar.autoupdatingCurrent.date(from: components) {
                time = date
            }
        }
    }

    /// 許可 1 件分の説明行。isGranted は許可済みバッジの表示に使う
    private func permissionRow(title: Text, detail: Text, isGranted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                title
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                if isGranted {
                    // ja: 許可済み
                    Text("Allowed")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.warmWhite.opacity(0.4))
                }
            }
            detail
                .font(.system(size: 11))
                .foregroundStyle(Color.warmWhite.opacity(0.4))
        }
        .padding(.vertical, 16)
    }

    /// アラーム・通知の許可を順にリクエストし、両方の結果が出たら次のステップへ進む。
    /// 既に決定済み (許可/拒否) の場合、システムはダイアログを出さず現在の状態を返すため何度呼んでも安全。
    /// 通知はここでは認可だけ取り、夜リマインドのスケジュールはオンボーディング完了後の RootView 側 (.task) が行う
    private func requestPermissions() async {
        guard !isRequestingPermissions else { return }
        isRequestingPermissions = true
        alarmAuthorizationState = (try? await AlarmKitManager.requestAuthorization()) ?? AlarmKitManager.authorizationState
        // 通知拒否は夜リマインドが送れなくなるだけでコア体験は成立するため、エラーは無視して状態の再読込だけ行う
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        notificationAuthorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        hasRequestedPermissions = true
        isRequestingPermissions = false
        if !needsPermissionSettingsGuidance(
            alarmAuthorizationState: alarmAuthorizationState,
            notificationAuthorizationStatus: notificationAuthorizationStatus
        ) {
            withAnimation(.easeInOut(duration: 0.6)) { step = .practice }
        }
    }

    /// 現在の許可状態を OS から読み直して表示へ反映する
    private func refreshPermissionStates() async {
        alarmAuthorizationState = AlarmKitManager.authorizationState
        notificationAuthorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 入力内容を保存して再スケジュールし、成功したら儀式のサマリーへ進む
    /// (AlarmSettingPage.save と同じ update-or-insert / rollback / 再スケジュール完了待ちの流れ)。
    /// オンボーディングの完了はサマリーに続くペイウォールを閉じた時に行うため、ここでは完了フラグを立てない。
    /// ペイウォール表示中にアプリを kill されるとオンボーディングが再走するが、アラーム設定は永続化済みで、
    /// alarmSettingStep の onAppear が設定時刻を復元するため許容する (issue #140)
    private func save() {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        // @AppStorage の既定値 false は UserDefaults へ書き込まれないため、AlarmSetting を保存する前に
        // 未完了であることを明示的に書き込み、「AlarmSetting はあるが完了キーが無い」状態を作らない。
        // キーが無いと、RootView.init() の旧バージョンからの移行判定 (キーなし + アラーム設定あり = 完了扱い) が
        // 新規インストールの kill 復帰にも誤発動し、儀式のサマリーとペイウォールを飛ばしてホームへ進んでしまう
        // (PR #142 Codex 指摘)
        UserDefaults.standard.set(false, forKey: .hasCompletedOnboarding)
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: time)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        if let alarmSetting = alarmSettings.first {
            alarmSetting.setTime(hour: hour, minute: minute)
            alarmSetting.setIsEnabled(isEnabled: true)
        } else {
            modelContext.insert(AlarmSetting(hour: hour, minute: minute))
        }
        do {
            try modelContext.save()
        } catch {
            // 永続化されていない変更を mainContext に残すと、次回の foreground 復帰で
            // reschedule がその未保存の値を fetch してしまうため、変更を破棄してから中断する
            modelContext.rollback()
            saveError = "\(error)"
            isSaving = false
            return
        }
        Task {
            await reschedule(modelContext: modelContext)
            // 再スケジュールの完了を待ってから、失敗時はオンボーディングに留まってエラーを表示する
            // (アラーム許可の拒否もここで schedule 失敗として現れるため、設定アプリへの誘導とセットで可視化される)
            if let error = UserDefaults.standard.string(forKey: .lastRescheduleError) {
                saveError = error
                await refreshPermissionStates()
                isSaving = false
            } else {
                isSaving = false
                withAnimation(.easeInOut(duration: 0.6)) { step = .ritualSummary }
            }
        }
    }
}

/// OnboardingPage の Preview。
/// index 0 は画面そのもの (コンセプトから開始)、index 1 以降は 1 画面ずつしか撮れない新設ステップの表示確認用。
/// SnapshotUITestPage / OnboardingPageSnapshotUITest の previewCount と個数を合わせる
struct OnboardingPage_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingPage()
                .modelContainer(PersistenceController.shared.container)
            stepPreview {
                OnboardingPainQuestionStepView<OnboardingWakeAnswer>(
                    question: Text("Can you wake up with a single alarm?"),
                    choices: [
                        .init(id: "onboarding_pain_wake_almost_never", label: Text("Almost never"), answer: .almostNever),
                        .init(id: "onboarding_pain_wake_sometimes", label: Text("Sometimes"), answer: .sometimes),
                        .init(id: "onboarding_pain_wake_almost_always", label: Text("Almost always"), answer: .almostAlways),
                    ],
                    onSelect: { _ in }
                )
            }
            stepPreview {
                OnboardingPainQuestionStepView<OnboardingMorningSatisfactionAnswer>(
                    question: Text("Are you happy with how your mornings begin?"),
                    choices: [
                        .init(id: "onboarding_pain_satisfaction_not_really", label: Text("No, not really"), answer: .notReally),
                        .init(id: "onboarding_pain_satisfaction_somewhat", label: Text("Somewhat"), answer: .somewhat),
                        .init(id: "onboarding_pain_satisfaction_mostly", label: Text("Mostly"), answer: .mostly),
                    ],
                    onSelect: { _ in }
                )
            }
            stepPreview {
                OnboardingPainQuestionStepView<OnboardingFirstMinutesAnswer>(
                    question: Text("What do your first minutes of the day look like?"),
                    choices: [
                        .init(id: "onboarding_first_minutes_scrolling", label: Text("Scrolling my phone"), answer: .scrolling),
                        .init(id: "onboarding_first_minutes_rushing", label: Text("Rushing to start the day"), answer: .rushing),
                        .init(id: "onboarding_first_minutes_ritual", label: Text("I have a morning ritual"), answer: .ritual),
                    ],
                    onSelect: { _ in }
                )
            }
            stepPreview {
                OnboardingPainQuestionStepView<OnboardingDayBeginAnswer>(
                    question: Text("When does your day really begin?"),
                    choices: [
                        .init(id: "onboarding_day_begin_morning", label: Text("In the morning"), answer: .morning),
                        .init(id: "onboarding_day_begin_noon", label: Text("Around noon"), answer: .noon),
                        .init(id: "onboarding_day_begin_evening", label: Text("By evening, finally"), answer: .evening),
                    ],
                    onSelect: { _ in }
                )
            }
            stepPreview {
                OnboardingPainQuestionStepView<OnboardingUndoneGoalAnswer>(
                    question: Text("Is there something you keep telling yourself you'll do?"),
                    choices: [
                        .init(id: "onboarding_undone_goal_yes", label: Text("Yes, and it stays undone"), answer: .undone),
                        .init(id: "onboarding_undone_goal_a_few", label: Text("A few things"), answer: .aFew),
                        .init(id: "onboarding_undone_goal_none", label: Text("Not really"), answer: .notReally),
                    ],
                    onSelect: { _ in }
                )
            }
            stepPreview {
                OnboardingBirthYearStepView(
                    year: .constant(1990),
                    yearRange: 1900...2026,
                    onContinue: {},
                    onSkip: {}
                )
            }
            stepPreview {
                OnboardingMorningsResultStepView(
                    // 年をまたいでも撮影結果が変わらないよう、現在年を固定した 1990 年生まれの提示を出す
                    variant: morningsResultVariant(birthYear: 1990, currentYear: 2026),
                    onContinue: {}
                )
            }
            stepPreview {
                OnboardingMementoMoriStepView(onContinue: {})
            }
            stepPreview {
                OnboardingRitualSummaryStepView(
                    alarmTime: Calendar.autoupdatingCurrent.date(bySettingHour: 7, minute: 0, second: 0, of: .now) ?? .now,
                    note: .startsTomorrow,
                    onBegin: {}
                )
            }
        }
    }

    /// 新設ステップの Preview を、実画面と同じ背景 (墨) と前景 (温白) で包む
    private static func stepPreview<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            content()
        }
        .foregroundStyle(Color.warmWhite)
    }
}
