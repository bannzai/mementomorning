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
            Task { await reschedule(modelContext: PersistenceController.shared.container.mainContext) }
        }
    }
}

/// ルート画面。通知から開く画面の提示と、朝の問いの提示、夜リマインドの登録を担う
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

    var body: some View {
        ContentView()
            .fullScreenCover(isPresented: $isMorningQuestionPresented) {
                MorningQuestionPage()
            }
            .sheet(isPresented: $notificationRouter.isNightReflectionPresented) {
                NightReflectionPage(notificationDate: notificationRouter.nightReflectionNotificationDate)
            }
            .task {
                // ユニットテストは TEST_HOST で実アプリをホスト起動するため、テスト中に通知の認可ダイアログが走らないよう打ち切る
                if isUnitTest { return }
                await NightReminder.requestAuthorizationAndSchedule()
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
    }

    /// 朝の問い画面の提示状態を最新化する。
    /// 回答が成立する (MorningAnswer が保存される) と MorningQuestionPage 自身が dismiss するため、ここでは提示のみ行う
    private func updateMorningQuestionPresentation() {
        // ユニットテストは TEST_HOST で実アプリをホスト起動するため、
        // シミュレータに残った発火記録でテスト中に全画面カバーが提示されないよう打ち切る
        if isUnitTest { return }
        let now = Date.now
        let answeredDates: Set<Date> = fetchMorningAnswer(answeredDate: now, modelContext: modelContext) != nil
            ? [Calendar.current.startOfDay(for: now)]
            : []
        if isMorningQuestionPending(now: now, alarmFiredDate: MementoMorning.lastAlarmFiredDate(), answeredDates: answeredDates) {
            isMorningQuestionPresented = true
        }
    }
}
