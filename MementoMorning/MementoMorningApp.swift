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
        // 課金判定 (PremiumEntitlement) は StopAlarmIntent など View 外からも参照するため、View の登場を待たず起動直後に初期化する
        PremiumEntitlement.configureIfPossible()
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
            // 連続追撃カウントは今日の回答が済んでいる時だけリセットする。
            // openAppWhenRun による foreground 復帰でもここは走るため、無条件のリセットだと
            // 未回答のまま停止するたびにカウントが 0 に戻り、無料枠のスヌーズ上限に到達しない (PR #30 レビュー指摘)
            if hasTodayAnswer(modelContext: PersistenceController.shared.container.mainContext) {
                UserDefaults.standard.removeObject(forKey: .stopIntentChaseCount)
            }
            Task { await reschedule(modelContext: PersistenceController.shared.container.mainContext) }
        }
    }
}

/// ルート画面。通知から開く画面の提示と、夜リマインドの登録を担う
private struct RootView: View {
    @Bindable private var notificationRouter = NotificationRouter.shared

    var body: some View {
        ContentView()
            .sheet(isPresented: $notificationRouter.isNightReflectionPresented) {
                NightReflectionPage(notificationDate: notificationRouter.nightReflectionNotificationDate)
            }
            .task {
                // ユニットテストは TEST_HOST で実アプリをホスト起動するため、テスト中に通知の認可ダイアログが走らないよう打ち切る
                if isUnitTest { return }
                await NightReminder.requestAuthorizationAndSchedule()
            }
            .task {
                // 購入・復元・期限切れを課金判定キャッシュへ反映し続ける (未 configure なら即 return する)
                await PremiumEntitlement.observeCustomerInfo()
            }
    }
}
