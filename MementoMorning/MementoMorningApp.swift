import SwiftUI
import SwiftData
import UserNotifications

/// Memento Morning アプリのエントリポイント
@main
struct MementoMorningApp: App {
    /// 通知タップからの cold launch では View が現れる前に didReceive が呼ばれる。取りこぼさないよう .task ではなく init でデリゲートを設定する
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(PersistenceController.shared.container)
    }
}

/// ルート画面。通知から開く画面の提示と、夜リマインドの登録を担う
private struct RootView: View {
    @Bindable private var notificationRouter = NotificationRouter.shared

    var body: some View {
        ContentView()
            .sheet(isPresented: $notificationRouter.isNightReflectionPresented) {
                NightReflectionPage()
            }
            .task {
                await NightReminder.requestAuthorizationAndSchedule()
            }
    }
}
