import AVFoundation
import XCTest

@testable import MementoMorning

/// 疑似録画モード (issue #52) のフィクスチャ動画のテスト。
/// 疑似 E2E は「フィクスチャに既知の発話の音声トラックが入っていること」を前提に
/// 写真ライブラリ保存 → 文字起こし → 回答成立まで通すため、その前提が壊れていないことを検証する
final class DebugVideoAnswerFixtureTests: XCTestCase {
    /// 言語ごとのフィクスチャ動画が DEBUG ビルドのアプリバンドルに同梱されていること。
    /// 端末の言語に合うアセットしかシミュレータに無いため、英語版・日本語版の両方が要る
    func testFixturesAreBundledForEveryLanguage() throws {
        for language in [DebugVideoAnswerFixtureLanguage.english, .japanese] {
            XCTAssertNotNil(language.fixtureURL, "\(language.resourceName) が同梱されていない")
        }
    }

    /// 言語ごとのフィクスチャ動画が映像と音声の両方のトラックを持つこと (文字起こしの検証に音声トラックが要る)
    func testFixturesHaveVideoAndAudioTracks() async throws {
        for language in [DebugVideoAnswerFixtureLanguage.english, .japanese] {
            let asset = AVURLAsset(url: try XCTUnwrap(language.fixtureURL))
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            XCTAssertFalse(videoTracks.isEmpty, "\(language.resourceName) に映像トラックが無い")
            XCTAssertFalse(audioTracks.isEmpty, "\(language.resourceName) に音声トラックが無い")
            // 発話が入る長さがあること。1 秒未満だと無音の動画に差し替わっていても
            // トラックの有無だけでは気づけないため下限を置く
            let duration = try await asset.load(.duration)
            XCTAssertGreaterThan(duration.seconds, 1, "\(language.resourceName) が短すぎる")
        }
    }

    /// 端末の言語で使うフィクスチャが選ばれること (音声認識アセットと言語を揃えるための分岐)
    func testCurrentFixtureFollowsDeviceLanguage() {
        XCTAssertEqual(
            DebugVideoAnswerFixtureLanguage.current,
            Locale.current.language.languageCode?.identifier == "ja" ? .japanese : .english
        )
        XCTAssertEqual(debugVideoAnswerFixtureUtterance, DebugVideoAnswerFixtureLanguage.current.utterance)
        XCTAssertEqual(debugVideoAnswerFixtureURL, DebugVideoAnswerFixtureLanguage.current.fixtureURL)
    }

    /// 疑似録画の「録画結果」がバンドル外の一時ファイルとして複製されること。
    /// 本物の録画と同じく、写真ライブラリへの保存後に呼び出し側が削除できる必要がある
    func testCopyFixtureCreatesDeletableTemporaryFile() throws {
        let copiedURL = try copyDebugVideoAnswerFixtureToTemporaryDirectory()
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedURL.path))
        XCTAssertNotEqual(copiedURL, debugVideoAnswerFixtureURL)
        XCTAssertTrue(copiedURL.path.hasPrefix(FileManager.default.temporaryDirectory.path))
        try FileManager.default.removeItem(at: copiedURL)
    }

    /// 複製が呼び出しごとに別ファイルになること (連続で録画し直しても上書きし合わない)
    func testCopyFixtureCreatesUniqueFileEachTime() throws {
        let firstURL = try copyDebugVideoAnswerFixtureToTemporaryDirectory()
        let secondURL = try copyDebugVideoAnswerFixtureToTemporaryDirectory()
        XCTAssertNotEqual(firstURL, secondURL)
        try FileManager.default.removeItem(at: firstURL)
        try FileManager.default.removeItem(at: secondURL)
    }
}
