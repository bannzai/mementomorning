import Photos
import XCTest

@testable import MementoMorning

/// 動画回答の再生 (AnswerVideoPlayerPage) の判定のテスト (issue #80)
final class AnswerVideoPlayerTests: XCTestCase {
    func testAuthorizedIsReadable() {
        XCTAssertTrue(isPhotoLibraryReadableForVideoAnswer(photoLibraryStatus: .authorized))
    }

    func testLimitedIsReadable() {
        // limited (一部の写真のみ選択) でもアプリ自身が保存した資産は読み出せるため許可として扱う
        XCTAssertTrue(isPhotoLibraryReadableForVideoAnswer(photoLibraryStatus: .limited))
    }

    func testDeniedIsNotReadable() {
        XCTAssertFalse(isPhotoLibraryReadableForVideoAnswer(photoLibraryStatus: .denied))
    }

    func testRestrictedIsNotReadable() {
        XCTAssertFalse(isPhotoLibraryReadableForVideoAnswer(photoLibraryStatus: .restricted))
    }

    func testNotDeterminedIsNotReadable() {
        XCTAssertFalse(isPhotoLibraryReadableForVideoAnswer(photoLibraryStatus: .notDetermined))
    }

    func testMissingAssetReturnsNil() {
        // 写真アプリで削除された動画 (存在しない localIdentifier) は見つからず nil になる (再生画面では「写真アプリにありません」の表示)
        XCTAssertNil(fetchVideoAnswerAsset(videoAssetIdentifier: "missing-video-asset"))
    }
}
