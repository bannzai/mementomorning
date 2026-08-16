import XCTest

extension XCUIApplication {
    /// 多言語スクリーンショット撮影用に XCUIApplication を生成する。
    /// isSnapshotUITest で MementoMorningApp を SnapshotUITestPage へ分岐させ、
    /// isUITest で永続化をメモリ内に切り替える (MementoMorning/Utils/Environments.swift のフラグ名に合わせる)
    static func instantiate() -> Self {
        let app = self.init()
        app.launchArguments += ["isUITest"]
        app.launchArguments += ["isSnapshotUITest"]
        return app
    }
}
