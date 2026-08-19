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

    func testMissingAssetReturnsNilPlayerItem() async {
        // 写真アプリで削除された動画 (存在しない localIdentifier) は再生できず nil になる
        let playerItem = await loadVideoAnswerPlayerItem(videoAssetIdentifier: "missing-video-asset")
        XCTAssertNil(playerItem)
    }
}
