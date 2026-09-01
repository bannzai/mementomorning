import Speech
import XCTest

@testable import MementoMorning

/// 動画回答の文字起こしの判定 (isTranscriptionAvailable / shouldApplyTranscription) のテスト。
/// 文字起こしの実行可否と、遅れて届いた結果を回答へ適用してよいかの分岐を網羅する
final class VideoAnswerTranscriberTests: XCTestCase {
    func testAuthorizedAndAvailableAndOnDeviceIsTranscribable() {
        XCTAssertTrue(
            isTranscriptionAvailable(
                authorizationStatus: .authorized,
                isRecognizerAvailable: true,
                supportsOnDeviceRecognition: true
            )
        )
    }

    func testDeniedIsNotTranscribable() {
        XCTAssertFalse(
            isTranscriptionAvailable(
                authorizationStatus: .denied,
                isRecognizerAvailable: true,
                supportsOnDeviceRecognition: true
            )
        )
    }

    func testRestrictedIsNotTranscribable() {
        XCTAssertFalse(
            isTranscriptionAvailable(
                authorizationStatus: .restricted,
                isRecognizerAvailable: true,
                supportsOnDeviceRecognition: true
            )
        )
    }

    func testNotDeterminedIsNotTranscribable() {
        // 未決定はリクエストで決定させてから判定する前提のため、そのままでは実行できない扱いにする
        XCTAssertFalse(
            isTranscriptionAvailable(
                authorizationStatus: .notDetermined,
                isRecognizerAvailable: true,
                supportsOnDeviceRecognition: true
            )
        )
    }

    func testUnavailableRecognizerIsNotTranscribable() {
        XCTAssertFalse(
            isTranscriptionAvailable(
                authorizationStatus: .authorized,
                isRecognizerAvailable: false,
                supportsOnDeviceRecognition: true
            )
        )
    }

    func testWithoutOnDeviceRecognitionIsNotTranscribable() {
        // オンデバイス非対応の言語ではサーバー認識へフォールバックせず、仮テキストのまま手動編集に委ねる
        XCTAssertFalse(
            isTranscriptionAvailable(
                authorizationStatus: .authorized,
                isRecognizerAvailable: true,
                supportsOnDeviceRecognition: false
            )
        )
    }

    func testPendingTranscriptionWithSameVideoIsApplied() {
        XCTAssertTrue(
            shouldApplyTranscription(
                currentStatus: .pending,
                currentVideoAssetIdentifier: "asset-1",
                transcribedVideoAssetIdentifier: "asset-1"
            )
        )
    }

    func testEditedTextIsNotOverwritten() {
        // ユーザーが先に手で直した回答を、後から届いた文字起こし結果で上書きしない
        XCTAssertFalse(
            shouldApplyTranscription(
                currentStatus: .completed,
                currentVideoAssetIdentifier: "asset-1",
                transcribedVideoAssetIdentifier: "asset-1"
            )
        )
    }

    func testRerecordedVideoIsNotOverwritten() {
        // 同じ日に録り直した新しい動画の回答を、古い動画の文字起こし結果で上書きしない
        XCTAssertFalse(
            shouldApplyTranscription(
                currentStatus: .pending,
                currentVideoAssetIdentifier: "asset-2",
                transcribedVideoAssetIdentifier: "asset-1"
            )
        )
    }

    func testTextAnswerIsNotOverwritten() {
        // 動画の後にテキストで答え直した回答 (videoAssetIdentifier が消えている) は文字起こしの対象にしない
        XCTAssertFalse(
            shouldApplyTranscription(
                currentStatus: nil,
                currentVideoAssetIdentifier: nil,
                transcribedVideoAssetIdentifier: "asset-1"
            )
        )
    }
}
