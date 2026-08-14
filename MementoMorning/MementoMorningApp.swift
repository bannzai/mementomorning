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
            switch newValue {
            case .active:
                // ユーザーがアプリを開けた (openAppWhenRun の成功または手動起動) なら追撃ループから抜けられているため、
                // issue #2 スパイクの連続追撃カウントをリセットする
                UserDefaults.standard.removeObject(forKey: .stopIntentChaseCount)
                Task {
                    await reschedule(modelContext: PersistenceController.shared.container.mainContext)
                    await NightReminder.requestAuthorizationAndSchedule(todayAnswerText: todayAnswerText())
                }
            case .background:
                // アプリ内で今日の回答が作られた直後の状態を夜リマインドへ反映するため、離脱時にも登録し直す
                Task { await NightReminder.requestAuthorizationAndSchedule(todayAnswerText: todayAnswerText()) }
            default:
                break
            }
        }
    }

    /// 夜リマインドの本文に引用する、今日の回答の本文。未回答なら nil
    @MainActor private func todayAnswerText() -> String? {
        MorningAnswer.answer(
            day: .now,
            calendar: .current,
            modelContext: PersistenceController.shared.container.mainContext
        )?.text
    }
}

/// ルート画面。通知から開く画面の提示を担う
private struct RootView: View {
    @Bindable private var notificationRouter = NotificationRouter.shared

    var body: some View {
        ContentView()
            .sheet(isPresented: $notificationRouter.isNightReflectionPresented) {
                NightReflectionPage(notificationDate: notificationRouter.nightReflectionNotificationDate)
            }
    }
}
