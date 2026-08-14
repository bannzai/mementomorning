import SwiftUI
import SwiftData
import UserNotifications

/// Memento Morning アプリのエントリポイント
@main
struct MementoMorningApp: App {
    /// アプリのライフサイクル状態
    @Environment(\.scenePhase) private var scenePhase

    /// 通知タップからの cold launch では View が現れる前に didReceive が呼ばれる。取りこぼさないよう .task ではなく init でデリゲートを設定する
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(PersistenceController.shared.container)
        // initial: true でコールドローンチ時 (既に .active で onChange が発火しないケース) もカバーする。
        // reschedule は冪等 + 直列化済みのため、初回に二重で呼ばれても問題ない
        .onChange(of: scenePhase, initial: true) { _, newValue in
            // ユニットテストは TEST_HOST で実アプリをホスト起動するため、
            // テスト中に認可ダイアログ・OS アラームの登録が走らないようここで打ち切る
            if isUnitTest { return }
            guard newValue == .active else { return }
            // ユーザーがアプリを開けた (openAppWhenRun の成功または手動起動) なら追撃ループから抜けられているため、
            // issue #2 スパイクの連続追撃カウントをリセットする
            UserDefaults.standard.removeObject(forKey: .stopIntentChaseCount)
            Task { await reschedule(modelContext: PersistenceController.shared.container.mainContext) }
        }
    }
}

/// ルート画面。オンボーディングとホームの切り替え、通知から開く画面の提示、夜リマインドの登録を担う
private struct RootView: View {
    @Bindable private var notificationRouter = NotificationRouter.shared
    /// オンボーディング完了済みかどうか。未完了の間はオンボーディングを表示し、
    /// 通知の認可リクエストもオンボーディング側の許可ステップに委ねる (起動直後にダイアログを出さない)
    @AppStorage(.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = false

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                ContentView()
                    .sheet(isPresented: $notificationRouter.isNightReflectionPresented) {
                        NightReflectionPage(notificationDate: notificationRouter.nightReflectionNotificationDate)
                    }
                    .task {
                        // ユニットテストは TEST_HOST で実アプリをホスト起動するため、テスト中に通知の認可ダイアログが走らないよう打ち切る
                        if isUnitTest { return }
                        // オンボーディングの許可ステップで認可済み (または拒否済み) のため、ここではダイアログなしで夜リマインドの登録だけが走る
                        await NightReminder.requestAuthorizationAndSchedule()
                    }
            } else {
                OnboardingPage()
                    .transition(.opacity)
            }
        }
        // オンボーディング完了時はスライドではなくフェードでホームへ切り替える (デザインの画面遷移規約)
        .animation(.easeInOut(duration: 0.6), value: hasCompletedOnboarding)
    }
}
