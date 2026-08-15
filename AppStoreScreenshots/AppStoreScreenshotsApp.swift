import SwiftUI

/// AppStoreScreenshots ターゲットの起動エントリ。
/// 撮影対象 (スクショページの Preview) 一覧を表示し、UITest がボタンをタップして各ページへ遷移する
@main
struct AppStoreScreenshotsApp: App {
    var body: some Scene {
        WindowGroup {
            AppStoreScreenshotsRootPage()
        }
    }
}
