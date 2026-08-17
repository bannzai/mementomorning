import SwiftUI
import SwiftData
import UIKit
import UserNotifications

/// Memento Morning アプリのエントリポイント
@main
struct MementoMorningApp: App {
    /// アプリのライフサイクル状態
    @Environment(\.scenePhase) private var scenePhase

    /// 通知タップからの cold launch では View が現れる前に didReceive が呼ばれる。取りこぼさないよう .task ではなく init でデリゲートを設定する
    init() {
        #if DEBUG
        if isSnapshotUITest {
            // 多言語スクリーンショットは SwiftData をメモリ内へ切り替えるが (isUITest)、UserDefaults は
            // シミュレータに残った以前の状態 (課金フラグ・デバッグ上書き・直近エラー) を引き継ぐ。
            // 撮影結果が端末の状態に依存しないよう、表示へ影響するキーを既知値 (未設定) へ戻す
            UserDefaults.standard.removeObject(forKey: .premiumEntitlementActive)
            UserDefaults.standard.removeObject(forKey: .debugPremiumOverride)
            UserDefaults.standard.removeObject(forKey: .lastRescheduleError)
        }
        #endif
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        // 課金判定 (PremiumEntitlement) は StopAlarmIntent など View 外からも参照するため、View の登場を待たず起動直後に初期化する。
        // 多言語スクリーンショット撮影中は configure しない (Config.local の API キー有無や通信状況で
        // Paywall の表示が環境ごとに変わるため、未 configure の見本価格に固定する)
        if !isSnapshotUITest {
            PremiumEntitlement.configureIfPossible()
        }
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if isSnapshotUITest {
                // 多言語スクリーンショット撮影では本番のルート分岐 (オンボーディング・朝の問い提示) を通さず、
                // 撮影対象 (本番画面の Preview) の一覧を直接表示する
                SnapshotUITestPage()
                    // 本番 RootView と同じテーマ (ダーク固定 + 温白アクセント) で撮影する
                    .preferredColorScheme(.dark)
                    .tint(Color.warmWhite)
            } else {
                RootView()
            }
            #else
            RootView()
            #endif
        }
        .modelContainer(PersistenceController.shared.container)
        // initial: true でコールドローンチ時 (既に .active で onChange が発火しないケース) もカバーする。
        // reschedule は冪等 + 直列化済みのため、初回に二重で呼ばれても問題ない
        .onChange(of: scenePhase, initial: true) { _, newValue in
            // ユニットテストは TEST_HOST で実アプリをホスト起動するため、
            // テスト中に認可ダイアログ・OS アラームの登録が走らないようここで打ち切る。
            // 多言語スクリーンショット撮影中も、撮影画面の上に認可ダイアログが被らないよう打ち切る
            if isUnitTest || isSnapshotUITest { return }
            switch newValue {
            case .active:
                // 連続追撃カウント (スヌーズ消費数) のリセットは reschedule が行う
                // (今日の回答が成立している時だけリセットする。回答の保存フローも同じ reschedule を通る)
                Task {
                    await reschedule(modelContext: PersistenceController.shared.container.mainContext)
                    do {
                        let answerText = try todayAnswerText()
                        // ロック画面の「今日の目標」(Live Activity) を最新化する。
                        // システムの制約 (約 8 時間) で自動終了した Live Activity の再開もここで行う
                        // (取得に失敗した時は、表示中の Live Activity を未回答と誤認して終了しないようスキップする)
                        await refreshTodayAnswerLiveActivity(todayAnswerText: answerText)
                        // オンボーディング未完了の間は、通知の認可リクエストをオンボーディングの許可ステップに委ねるため夜リマインドを登録しない
                        // (起動直後にダイアログを出さない。完了直後の登録は RootView 側の task が行う)
                        guard UserDefaults.standard.bool(forKey: .hasCompletedOnboarding) else { return }
                        await NightReminder.requestAuthorizationAndSchedule(todayAnswerText: answerText)
                    } catch {
                        // 回答の取得に失敗した時は、登録済みのパーソナライズ通知を汎用文言で上書きしないよう再登録しない。次の scenePhase の変化で再試行される
                        print("[MementoMorningApp] failed to fetch today's answer: \(error)")
                    }
                }
            case .background:
                // アプリ内で今日の回答が作られた直後の状態を夜リマインドへ反映するため、離脱時にも登録し直す
                // (オンボーディング未完了の間は .active と同じ理由で登録しない)
                guard UserDefaults.standard.bool(forKey: .hasCompletedOnboarding) else { return }
                scheduleNightReminderWithBackgroundTaskAssertion()
            default:
                break
            }
        }
    }

    /// バックグラウンド遷移後に夜リマインドを登録し直す。
    /// 通常の Task はバックグラウンドで実行時間の保証がなく、認可状態の確認と通知の登録が終わる前にプロセスが停止し得るため、
    /// background task assertion で完了までの実行時間を確保する
    @MainActor private func scheduleNightReminderWithBackgroundTaskAssertion() {
        var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "night-reminder-schedule") {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
        Task {
            do {
                await NightReminder.requestAuthorizationAndSchedule(todayAnswerText: try todayAnswerText())
            } catch {
                // 回答の取得に失敗した時は、登録済みのパーソナライズ通知を汎用文言で上書きしないよう再登録しない。次の scenePhase の変化で再試行される
                print("[MementoMorningApp] failed to fetch today's answer: \(error)")
            }
            // 期限切れの expirationHandler が先に終了させている場合があるため、二重に終了させないよう .invalid を見てから終了する
            guard backgroundTaskIdentifier != .invalid else { return }
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }

    /// 夜リマインドの本文に引用する、今日の回答の本文。未回答なら nil。取得に失敗した場合は未回答と区別できるよう throw する
    @MainActor private func todayAnswerText() throws -> String? {
        try MorningAnswer.answer(
            day: .now,
            calendar: .current,
            modelContext: PersistenceController.shared.container.mainContext
        )?.text
    }
}

/// ルート画面。オンボーディングとホームの切り替え、通知から開く画面の提示、朝の問いの提示、オンボーディング完了直後の夜リマインド登録を担う
private struct RootView: View {
    @Bindable private var notificationRouter = NotificationRouter.shared
    /// アプリのライフサイクル状態。foreground 復帰のたびに朝の問いの提示判定をやり直すために監視する
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    /// 直近のアラーム発火日時 (epoch 秒。0 = 未記録)。StopAlarmIntent / Rescheduler が書き込む。
    /// Date は @AppStorage で扱えないため Double で監視し、読み取りは lastAlarmFiredDate() を使う
    @AppStorage(.lastAlarmFiredDate) private var lastAlarmFiredDate: Double = 0
    /// 朝の問い画面を提示中かどうか
    @State private var isMorningQuestionPresented = false
    /// オンボーディング完了済みかどうか。未完了の間はオンボーディングを表示し、
    /// 通知の認可リクエストもオンボーディング側の許可ステップに委ねる (起動直後にダイアログを出さない)
    @AppStorage(.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = false

    /// フラグ導入前のバージョンから更新した既存インストールの移行。
    /// キーが一度も書き込まれていない (nil) 場合に限り、アラーム設定済みなら完了扱いにしてオンボーディングへ戻さない。
    /// デバッグメニューのリセットは false を明示的に書き込むため、この移行の対象にならない
    init() {
        guard UserDefaults.standard.object(forKey: .hasCompletedOnboarding) == nil else { return }
        if ((try? PersistenceController.shared.container.mainContext.fetchCount(FetchDescriptor<AlarmSetting>())) ?? 0) > 0 {
            UserDefaults.standard.set(true, forKey: .hasCompletedOnboarding)
        }
    }

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                ContentView()
                    .fullScreenCover(isPresented: $isMorningQuestionPresented) {
                        MorningQuestionPage()
                            // 「回答するまで閉じられない」を明示する。fullScreenCover は現状スワイプでは閉じられないが、
                            // 意図をコードに固定し、提示方法を変えた時にもジェスチャで回避できないようにする
                            .interactiveDismissDisabled()
                    }
                    .sheet(isPresented: $notificationRouter.isNightReflectionPresented) {
                        NightReflectionPage(notificationDate: notificationRouter.nightReflectionNotificationDate)
                    }
                    .task {
                        // ユニットテストは TEST_HOST で実アプリをホスト起動するため、テスト中に通知の認可ダイアログが走らないよう打ち切る
                        if isUnitTest { return }
                        // オンボーディング完了直後は scenePhase が変化せず MementoMorningApp 側の再登録が走らないため、ここで登録する。
                        // 許可ステップで認可済み (または拒否済み) のため、ダイアログなしで夜リマインドの登録だけが走る
                        do {
                            await NightReminder.requestAuthorizationAndSchedule(
                                todayAnswerText: try MorningAnswer.answer(
                                    day: .now,
                                    calendar: .current,
                                    modelContext: PersistenceController.shared.container.mainContext
                                )?.text
                            )
                        } catch {
                            // 回答の取得に失敗した時は、登録済みのパーソナライズ通知を汎用文言で上書きしないよう再登録しない。次の scenePhase の変化で再試行される
                            print("[RootView] failed to fetch today's answer: \(error)")
                        }
                    }
            } else {
                OnboardingPage()
                    .transition(.opacity)
            }
        }
        // ダークモード前提の唯一のテーマ (design_handoff_memento_morning/README.md)。
        // アクセントも温白に固定し、システム標準の青いリンク色を出さない。
        // オンボーディングも同じ世界観のため、ContentView ではなく両画面の親に当てる
        .preferredColorScheme(.dark)
        .tint(Color.warmWhite)
        // オンボーディング完了時はスライドではなくフェードでホームへ切り替える (デザインの画面遷移規約)
        .animation(.easeInOut(duration: 0.6), value: hasCompletedOnboarding)
        .task {
            // 購入・復元・期限切れを課金判定キャッシュへ反映し続ける (未 configure なら即 return する)。
            // オンボーディング中も購読を切らさないよう、ContentView ではなく親で開始する
            await PremiumEntitlement.observeCustomerInfo()
        }
        // initial: true でコールドローンチ直後 (openAppWhenRun による前面化を含む) も判定する
        .onChange(of: scenePhase, initial: true) { _, newValue in
            guard newValue == .active else { return }
            updateMorningQuestionPresentation()
        }
        // foreground 中に StopAlarmIntent.perform() や Rescheduler が発火を記録した場合に追従する
        .onChange(of: lastAlarmFiredDate) { _, _ in
            updateMorningQuestionPresentation()
        }
        // 前面に表示したまま日付が変わったら判定をやり直す (問いは発火した日の朝のもの。跨いだら閉じる)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            if isUnitTest { return }
            updateMorningQuestionPresentation()
            // 前日分の残バックアップ・追撃を掃除して新しい日の計画へ切り替える
            // (問いを閉じた後に前日のバックアップが鳴り続けないようにする)
            Task {
                await reschedule(modelContext: PersistenceController.shared.container.mainContext)
                // 前日の「今日の目標」をロック画面に残さない (新しい日の回答があればそれへ切り替える)。
                // 日付跨ぎでは消える方が正のため、取得の失敗は未回答 (終了) に倒す
                await refreshTodayAnswerLiveActivity(
                    todayAnswerText: (try? MorningAnswer.answer(
                        day: .now,
                        calendar: .current,
                        modelContext: PersistenceController.shared.container.mainContext
                    ))?.text
                )
            }
        }
    }

    /// 朝の問い画面の提示状態を最新化する。
    /// 提示 (未回答の朝) と解除 (日付跨ぎ・アラーム OFF・回答成立) の両方向へ反映する。
    /// 回答の成立時は MorningQuestionPage 自身も dismiss する
    private func updateMorningQuestionPresentation() {
        // ユニットテストは TEST_HOST で実アプリをホスト起動するため、
        // シミュレータに残った発火記録でテスト中に全画面カバーが提示されないよう打ち切る
        if isUnitTest { return }
        // オンボーディング中は fullScreenCover の提示先 (ContentView) が無く、朝の儀式より初期設定を優先する
        guard hasCompletedOnboarding else { return }
        // アラームを明示的に OFF にしたユーザーを問いに閉じ込めない (回答するまで閉じられない画面のため、
        // OFF の間は提示しない・提示中でも閉じる)
        let alarmSetting = (try? modelContext.fetch(FetchDescriptor<AlarmSetting>()))?.first
        guard let alarmSetting, alarmSetting.isEnabled else {
            isMorningQuestionPresented = false
            return
        }
        let now = Date.now
        let answer: MorningAnswer?
        do {
            answer = try MorningAnswer.answer(day: now, calendar: .current, modelContext: modelContext)
        } catch {
            // 回答状態が不明のまま「回答するまで閉じられない画面」を出し入れしない。
            // 現在の提示状態を維持し、次の再判定 (foreground 復帰・発火記録の変化・日付変更) に任せる
            print("[RootView] failed to fetch today's answer: \(error)")
            return
        }
        let answeredDates: Set<Date> = answer != nil ? [Calendar.current.startOfDay(for: now)] : []
        isMorningQuestionPresented = isMorningQuestionPending(
            now: now,
            alarmFiredDate: MementoMorning.lastAlarmFiredDate(),
            answeredDates: answeredDates
        )
    }
}
