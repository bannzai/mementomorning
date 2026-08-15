import AVFoundation
import Photos
import XCTest

@testable import MementoMorning

/// 動画回答の権限判定 (isVideoAnswerPermitted) のテスト。
/// 受け入れ条件「カメラ/マイク/写真の権限拒否時にテキスト入力へフォールバックする」の判定を網羅する
final class VideoAnswerGateTests: XCTestCase {
    func testAllAuthorizedIsPermitted() {
        XCTAssertTrue(
            isVideoAnswerPermitted(
                cameraStatus: .authorized,
                microphoneStatus: .authorized,
                photoLibraryStatus: .authorized
            )
        )
    }

    func testPhotoLibraryLimitedIsPermitted() {
        // limited (一部の写真のみ選択) でも資産の追加はできるため許可として扱う
        XCTAssertTrue(
            isVideoAnswerPermitted(
                cameraStatus: .authorized,
                microphoneStatus: .authorized,
                photoLibraryStatus: .limited
            )
        )
    }

    func testCameraDeniedFallsBackToText() {
        XCTAssertFalse(
            isVideoAnswerPermitted(
                cameraStatus: .denied,
                microphoneStatus: .authorized,
                photoLibraryStatus: .authorized
            )
        )
    }

    func testMicrophoneDeniedFallsBackToText() {
        XCTAssertFalse(
            isVideoAnswerPermitted(
                cameraStatus: .authorized,
                microphoneStatus: .denied,
                photoLibraryStatus: .authorized
            )
        )
    }

    func testPhotoLibraryDeniedFallsBackToText() {
        XCTAssertFalse(
            isVideoAnswerPermitted(
                cameraStatus: .authorized,
                microphoneStatus: .authorized,
                photoLibraryStatus: .denied
            )
        )
    }

    func testRestrictedFallsBackToText() {
        XCTAssertFalse(
            isVideoAnswerPermitted(
                cameraStatus: .restricted,
                microphoneStatus: .authorized,
                photoLibraryStatus: .authorized
            )
        )
        XCTAssertFalse(
            isVideoAnswerPermitted(
                cameraStatus: .authorized,
                microphoneStatus: .restricted,
                photoLibraryStatus: .authorized
            )
        )
        XCTAssertFalse(
            isVideoAnswerPermitted(
                cameraStatus: .authorized,
                microphoneStatus: .authorized,
                photoLibraryStatus: .restricted
            )
        )
    }

    func testNotDeterminedIsNotPermitted() {
        // 未決定はリクエストで決定させてから判定する前提のため、そのままでは利用できない扱いにする
        XCTAssertFalse(
            isVideoAnswerPermitted(
                cameraStatus: .notDetermined,
                microphoneStatus: .notDetermined,
                photoLibraryStatus: .notDetermined
            )
        )
    }
}
