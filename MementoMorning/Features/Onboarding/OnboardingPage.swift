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

/// 墨 (背景) #0B0C0E。design_handoff_memento_morning/README.md の Design Tokens に従う
private let inkColor = Color(red: 11 / 255, green: 12 / 255, blue: 14 / 255)
/// 温白 (前景) #E9E7E2
private let warmWhiteColor = Color(red: 233 / 255, green: 231 / 255, blue: 226 / 255)
/// 夜明けの微光 (アクセント) #C2A183。各画面 1 箇所までの制約があるため多用しない
private let dawnColor = Color(red: 194 / 255, green: 161 / 255, blue: 131 / 255)

/// 初回起動時のオンボーディング。
/// コンセプト提示 → アラーム・通知の許可 → 最初のアラーム設定、の 3 ステップを 1 画面内のフェードで進める
/// (デザイン: design_handoff_memento_morning の 1m「夜明けの一枚目」。画面遷移はフェードのみ)
struct OnboardingPage: View {
    /// オンボーディングの進行ステップ
    private enum Step {
        case concept
        case permission
        case alarmSetting
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

    var body: some View {
        ZStack {
            inkColor.ignoresSafeArea()
            dawnHorizon
            switch step {
            case .concept:
                conceptStep.transition(.opacity)
            case .permission:
                permissionStep.transition(.opacity)
            case .alarmSetting:
                alarmSettingStep.transition(.opacity)
            }
        }
        // オンボーディングは夜明け前の墨色が前提のため、システム設定に関わらずダークで描画する
        .preferredColorScheme(.dark)
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
                    .init(color: dawnColor.opacity(0), location: 0),
                    .init(color: dawnColor.opacity(0.14), location: 0.7),
                    .init(color: dawnColor.opacity(0.22), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
        }
        .overlay(alignment: .bottom) {
            // 地平線。中央が最も明るい 1pt のライン
            LinearGradient(
                colors: [dawnColor.opacity(0), dawnColor.opacity(0.55), dawnColor.opacity(0)],
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
                .foregroundStyle(warmWhiteColor.opacity(0.45))
                .padding(.top, 14)
            Spacer()
            VStack(spacing: 14) {
                Button {
                    withAnimation(.easeInOut(duration: 0.6)) { step = .permission }
                } label: {
                    // ja: はじめる
                    primaryButtonLabel(title: Text("Begin"))
                }
                .accessibilityIdentifier("onboarding_begin")
                // ja: 次の画面でアラームと通知の許可をお願いします
                Text("Alarm & notification permissions are requested next")
                    .font(.system(size: 10))
                    .foregroundStyle(warmWhiteColor.opacity(0.32))
            }
        }
        .foregroundStyle(warmWhiteColor)
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
                Divider().overlay(warmWhiteColor.opacity(0.08))
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
                        .foregroundStyle(warmWhiteColor.opacity(0.45))
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        // ja: 設定を開く
                        secondaryButtonLabel(title: Text("Open Settings"))
                    }
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
                    primaryButtonLabel(title: Text("Allow"))
                }
                .disabled(isRequestingPermissions)
                .accessibilityIdentifier("onboarding_allow_permissions")
                if hasRequestedPermissions {
                    Button {
                        withAnimation(.easeInOut(duration: 0.6)) { step = .alarmSetting }
                    } label: {
                        // ja: つづける
                        Text("Continue")
                            .font(.system(size: 13))
                            .foregroundStyle(warmWhiteColor.opacity(0.55))
                            .underline()
                    }
                    .accessibilityIdentifier("onboarding_continue")
                }
            }
        }
        .foregroundStyle(warmWhiteColor)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            await refreshPermissionStates()
        }
    }

    /// ステップ 3: 最初のアラーム設定
    private var alarmSettingStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ja: 最初のアラーム
            Text("Your first alarm")
                .font(.system(size: 25, weight: .light))
                .tracking(1.5)
            // ja: 答えるまで、アラームは鳴り続けます
            Text("The alarm keeps returning until you answer.")
                .font(.system(size: 12))
                .foregroundStyle(warmWhiteColor.opacity(0.45))
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
                // エラーメッセージはそのまま表示する (加工しない)。低彩度の世界観に合わせて赤は使わない
                Text(saveError)
                    .font(.system(size: 12))
                    .foregroundStyle(dawnColor)
                    .padding(.top, 14)
                if alarmAuthorizationState == .denied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        // ja: 設定を開く
                        secondaryButtonLabel(title: Text("Open Settings"))
                    }
                    .accessibilityIdentifier("onboarding_alarm_open_settings")
                    .padding(.top, 14)
                }
            }
            Spacer()
            Button {
                save()
            } label: {
                // ja: アラームをセットする
                primaryButtonLabel(title: Text("Set alarm"))
            }
            .disabled(isSaving)
            .accessibilityIdentifier("onboarding_set_alarm")
        }
        .foregroundStyle(warmWhiteColor)
        .padding(.top, 130)
        .padding(.horizontal, 36)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        .foregroundStyle(warmWhiteColor.opacity(0.4))
                }
            }
            detail
                .font(.system(size: 11))
                .foregroundStyle(warmWhiteColor.opacity(0.4))
        }
        .padding(.vertical, 16)
    }

    /// primary ボタン (温白地に墨文字の pill) のラベル
    private func primaryButtonLabel(title: Text) -> some View {
        title
            .font(.system(size: 15))
            .tracking(2.1)
            .foregroundStyle(inkColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(warmWhiteColor, in: Capsule())
    }

    /// secondary ボタン (ヘアライン枠のみの pill) のラベル
    private func secondaryButtonLabel(title: Text) -> some View {
        title
            .font(.system(size: 13))
            .tracking(1.8)
            .foregroundStyle(warmWhiteColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .overlay(Capsule().stroke(warmWhiteColor.opacity(0.18), lineWidth: 1))
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
            withAnimation(.easeInOut(duration: 0.6)) { step = .alarmSetting }
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
