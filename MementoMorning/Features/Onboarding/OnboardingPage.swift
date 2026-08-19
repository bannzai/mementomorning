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
/// コンセプト提示 → アラーム・通知の許可 → 回答の練習 → 最初のアラーム設定、の 4 ステップを 1 画面内のフェードで進める
/// (デザイン: design_handoff_memento_morning の 1m「夜明けの一枚目」。画面遷移はフェードのみ)。
/// 練習ステップは、朝の初回がぶっつけ本番の録画にならないよう事前に一度録画を試すチュートリアル (issue #44)。
/// カメラ・マイク・写真ライブラリ・音声認識の権限も、使い道の説明を見せてからここでまとめてリクエストする
struct OnboardingPage: View {
    /// オンボーディングの進行ステップ
    private enum Step {
        case concept
        case permission
        case practice
        case alarmSetting
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

    /// 現在のステップ
    @State private var step: Step = .concept
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
            case .permission:
                permissionStep.transition(.opacity)
            case .practice:
                practiceStep.transition(.opacity)
            case .alarmSetting:
                alarmSettingStep.transition(.opacity)
            }
        }
        // ダークテーマの指定は RootView が両画面の親でまとめて当てる
        .onChange(of: scenePhase) { _, newValue in
            // 設定アプリで許可を変更して戻ってきた場合に表示へ反映する
            guard newValue == .active else { return }
            Task { await refreshPermissionStates() }
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
            VStack(spacing: 14) {
                Button {
                    withAnimation(.easeInOut(duration: 0.6)) { step = .permission }
                } label: {
                    // ja: はじめる
                    Text("Begin")
                }
                .buttonStyle(PrimaryPillButtonStyle())
                .accessibilityIdentifier("onboarding_begin")
                // ja: 次の画面でアラームと通知の許可をお願いします
                Text("Alarm & notification permissions are requested next")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.warmWhite.opacity(0.32))
            }
        }
        .foregroundStyle(Color.warmWhite)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// ステップ 2: アラーム・通知の許可リクエスト
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

    /// ステップ 3: 回答の練習 (インカメラ録画のチュートリアル)。
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
                // ja: 今日死ぬとしたら、何をやりたいか
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

    /// ステップ 4: 最初のアラーム設定
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

    /// 入力内容を保存して再スケジュールし、成功したらオンボーディングを完了する
    /// (AlarmSettingPage.save と同じ update-or-insert / rollback / 再スケジュール完了待ちの流れ)
    private func save() {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
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
                hasCompletedOnboarding = true
            }
        }
    }
}

/// OnboardingPage の Preview
struct OnboardingPage_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingPage()
            .modelContainer(PersistenceController.shared.container)
    }
}
