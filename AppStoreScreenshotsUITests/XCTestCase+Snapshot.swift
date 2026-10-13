import XCTest

extension XCTestCase {
    /// 表示中のスクショページを撮影して結果バンドルに残す。
    /// name は {file}---{function}---{language}---{index} で、scripts/generate_screenshots/organize_appstore_screenshots.sh が解析する。
    ///
    /// 環境変数 SNAPSHOT_HOST_CAPTURE_DIR (シェル側は TEST_RUNNER_SNAPSHOT_HOST_CAPTURE_DIR で渡す) がある時は
    /// XCTAttachment を作らず、ホスト側の撮影に切り替える。iPhone Duo の内側ディスプレイは XCTest の API では
    /// ストア仕様の寸法で撮れない (XCUIScreen.screens[1].screenshot() は 90 度回った 2006×2852 で、仕様の 2853×2007 に 1px 足りない。
    /// appstore-screenshot-builder skill references/iphone-duo.md の実測) ため、ページを表示した状態で待機し、
    /// ホストが `xcrun simctl io <UDID> screenshot --display=primary-1` で撮る (外側もホームインジケーターの写り込みを
    /// 画像で検査して撮り直すためホスト側で撮る。scripts/generate_screenshots/appstore_screenshot_env.sh の is_host_capture_device)。
    /// 同期は目印のファイルで取る:
    /// テストが <name>.ready を書く → ホストが撮影して <name>.done を書く → テストが次へ進む
    /// (simulator のプロセスはホストのファイルシステムに書ける)
    func addSnapshot(app: XCUIApplication, name: String) {
        guard let hostCaptureDirectory = ProcessInfo.processInfo.environment["SNAPSHOT_HOST_CAPTURE_DIR"],
              !hostCaptureDirectory.isEmpty else {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            return
        }

        let readyFile = URL(fileURLWithPath: hostCaptureDirectory).appendingPathComponent("\(name).ready")
        let doneFile = URL(fileURLWithPath: hostCaptureDirectory).appendingPathComponent("\(name).done")
        // 前回の実行の残骸で待たずに進んでしまわないよう、done を消してから ready を置く
        try? FileManager.default.removeItem(at: doneFile)
        XCTAssertTrue(
            FileManager.default.createFile(atPath: readyFile.path, contents: nil),
            "ホスト撮影の目印を書けません: \(readyFile.path)"
        )

        // ホストの撮影 (simctl のスクリーンショット + alpha 除去) は数秒で終わるため、
        // それより十分長い 120 秒を上限にし、ホストの監視が動いていない時にテストを無期限に止めない
        let deadline = Date().addingTimeInterval(120)
        while !FileManager.default.fileExists(atPath: doneFile.path) {
            if Date() >= deadline {
                XCTFail("ホスト側の撮影完了 (\(doneFile.path)) を 120 秒待っても現れません。scripts/generate_screenshots/capture_host_screenshots.sh が動いているか確認してください")
                return
            }
            sleep(1)
        }
    }
}
