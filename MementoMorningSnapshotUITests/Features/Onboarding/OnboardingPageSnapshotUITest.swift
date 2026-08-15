import XCTest

/// OnboardingPage の Preview を全対象言語で撮影する SnapshotUITest。
/// XCTAttachment 名 ({file}---{function}---{language}---{index}) を
/// scripts/snapshot_ui_tests/organize_screenshots.sh が解析して言語別に整理する
final class OnboardingPageSnapshotUITest: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        // runsForEachTargetApplicationUIConfiguration で実行すると Locale の取得がうまくいかず全部 en になる (取り込み元 Focus での実測)
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 撮影対象の PreviewProvider 名。SnapshotUITestPage のボタンラベルと一致させる
    let previewType = "OnboardingPage_Previews"
    /// PreviewProvider が持つ Preview の個数。_allPreviews を型から辿れないためハードコードする (取り込み元 Focus と同じ制約)
    let previewCount = 1

    func testSnapshot() throws {
        // アプリはダークモード前提の唯一のテーマのため、ステータスバー等の描画も dark に固定する
        XCUIDevice.shared.appearance = .dark
        let fileName = URL(fileURLWithPath: #file).deletingPathExtension().lastPathComponent
        let functionName = #function.replacingOccurrences(of: "()", with: "")

        filteredLanguages().forEach { (language, languageWithRegion) in
            debugPrint("Start: ", #file, #function, language)

            let app = XCUIApplication.instantiate()
            app.launchArguments += ["-AppleLanguages", "(\(language))"]
            // 日付等のロケール依存表示を対象地域の形式で撮影するため、リージョン付きタグも渡す
            app.launchArguments += ["-AppleLocale", languageWithRegion]
            app.launch()

            for index in (0..<previewCount) {
                app.buttons["\(previewType)_\(index)"].firstMatch.tap()
                sleep(1)

                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.name = "\(fileName)---\(functionName)---\(language)---\(index)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}
