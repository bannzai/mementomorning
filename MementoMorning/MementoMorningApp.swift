import SwiftUI
import SwiftData

/// Memento Morning アプリのエントリポイント
@main
struct MementoMorningApp: App {
    /// アプリのライフサイクル状態
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
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
