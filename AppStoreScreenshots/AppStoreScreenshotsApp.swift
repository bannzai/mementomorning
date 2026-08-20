import SwiftUI

/// AppStoreScreenshots ターゲットの起動エントリ。
/// 撮影対象 (スクショページの Preview) 一覧を表示し、UITest がボタンをタップして各ページへ遷移する
@main
struct AppStoreScreenshotsApp: App {
    var body: some Scene {
        WindowGroup {
            AppStoreScreenshotsRootPage()
                // ホームインジケーターを非表示にする。NavigationView の遷移先に付けるだけでは効かず、
                // 明背景バリアントの 6.5 インチ (iPhone 13 Pro Max) で写り込むことを実測したため root に付ける (PR #89)
                .persistentSystemOverlays(.hidden)
        }
    }
}
