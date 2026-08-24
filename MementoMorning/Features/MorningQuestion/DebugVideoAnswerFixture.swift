import Foundation

extension String {
    /// 疑似録画モード (カメラの実撮影だけをフィクスチャ動画に差し替える) の有効/無効を保存する UserDefaults キー
    /// (DebugMenuPage から切り替える)
    static let debugSimulateVideoAnswer = "debugSimulateVideoAnswer"
}

/// 疑似録画モードが有効かどうか。
/// シミュレータにはカメラが無く動画回答のパイプラインを検証できないため、
/// 有効な間は VideoAnswerCamera が AVCapture を使わず、録画停止でフィクスチャ動画を「録画結果」として返す
/// (以降の写真ライブラリ保存・文字起こし・回答成立は本物のコードを通す。issue #52)。
/// 効果は開発者メニューを解放したビルド (isDeveloperMenuUnlocked) に限る (issue #128)
var isDebugSimulateVideoAnswerEnabled: Bool {
    isDeveloperMenuUnlocked && UserDefaults.standard.bool(forKey: .debugSimulateVideoAnswer)
}

/// フィクスチャ動画の言語ごとの発話と、動画のリソース名 (拡張子なし)。
/// 発話は文字起こし (VideoAnswerTranscriber) が回答テキストに入れる期待値で、
/// 動画の生成元である scripts/generate_video_answer_fixture.sh の UTTERANCE_EN / UTTERANCE_JA と同じ文言にする
enum DebugVideoAnswerFixtureLanguage: String {
    /// 英語 (アプリの開発言語。日本語以外の環境で使う)
    case english = "en"
    /// 日本語
    case japanese = "ja"

    /// 端末の言語に合うフィクスチャ。
    /// シミュレータには端末の言語のオンデバイス音声認識アセットしか入っておらず、
    /// 言語が合わないと文字起こしが kLSRErrorDomain 101 (No Assistant asset for language ...) で失敗するため、
    /// SFSpeechRecognizer(locale: .current) が使う言語に合わせて選ぶ (iOS 26.5 simulator で実測)
    static var current: DebugVideoAnswerFixtureLanguage {
        Locale.current.language.languageCode?.identifier == "ja" ? .japanese : .english
    }

    /// フィクスチャ動画に含まれる発話 (文字起こしの期待値)
    var utterance: String {
        switch self {
        case .english:
            return "I want to see the ocean with my family today."
        case .japanese:
            return "今日は家族と海を見に行きたい"
        }
    }

    /// バンドル内のリソース名 (拡張子なし)。
    /// Release ビルドからは MementoMorning ターゲットの EXCLUDED_SOURCE_FILE_NAMES でこの名前のファイルを除外している
    var resourceName: String {
        "DebugVideoAnswerFixture_\(rawValue)"
    }

    /// バンドル内の URL。DEBUG ビルドには同梱されているため通常 nil にならない
    var fixtureURL: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: "mov")
    }
}

/// 端末の言語に合うフィクスチャ動画のバンドル内 URL
var debugVideoAnswerFixtureURL: URL? {
    DebugVideoAnswerFixtureLanguage.current.fixtureURL
}

/// 端末の言語に合うフィクスチャ動画の発話 (文字起こしの期待値)
var debugVideoAnswerFixtureUtterance: String {
    DebugVideoAnswerFixtureLanguage.current.utterance
}

/// 疑似録画の「録画結果」を作る。フィクスチャ動画を一時ディレクトリの一意なファイルへ複製して返す。
/// 本物の録画と同じく、呼び出し側 (写真ライブラリへの保存後) が削除してよいファイルにするため、
/// バンドル内の URL をそのまま返さず複製する
func copyDebugVideoAnswerFixtureToTemporaryDirectory() throws -> URL {
    guard let debugVideoAnswerFixtureURL else {
        throw CocoaError(.fileNoSuchFile)
    }
    let destinationURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("video-answer-\(UUID().uuidString)")
        .appendingPathExtension("mov")
    try FileManager.default.copyItem(at: debugVideoAnswerFixtureURL, to: destinationURL)
    return destinationURL
}
