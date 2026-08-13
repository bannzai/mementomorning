import SwiftUI
import SwiftData

/// Memento Morning アプリのエントリポイント
@main
struct MementoMorningApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(PersistenceController.shared.container)
    }
}
