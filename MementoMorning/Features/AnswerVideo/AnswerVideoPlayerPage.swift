import AVKit
import Photos
import SwiftUI

/// 動画回答の再生画面 (issue #80)。写真ライブラリのアルバム「Memento Morning」へ保存した回答動画を、
/// ジャーナル・夜の振り返りから見返すためのシート。動画は写真アプリの管理下にあるため、
/// ユーザーが削除済み・写真の権限が取り消し済みの場合はその旨だけを静かに表示する
struct AnswerVideoPlayerPage: View {
    /// 再生する動画の PHAsset localIdentifier (MorningAnswer.videoAssetIdentifier)
    let videoAssetIdentifier: String

    @State private var state: VideoAnswerReplayState = .loading

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            switch state {
            case .loading:
                ProgressView()
                    .tint(Color.warmWhite)
            case .playable(let player):
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .accessibilityIdentifier("answer_video_player")
            case .photoLibraryDenied:
                // ja: 動画を見返すには、設定で写真へのアクセスを許可してください
                unavailableText("Allow access to Photos in Settings to watch the video.")
            case .notFound:
                // ja: この動画は写真アプリにありません
                unavailableText("This video is no longer in Photos.")
            case .loadFailed:
                VStack(spacing: 20) {
                    // ja: 動画を読み込めませんでした。通信状態を確認してもう一度お試しください
                    unavailableText("Couldn't load the video. Check your connection and try again.")
                    Button {
                        state = .loading
                        Task { await load() }
                    } label: {
                        // ja: もう一度試す
                        Text("Try again")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.warmWhite.opacity(0.55))
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("answer_video_retry_button")
                }
            }
        }
        .presentationDragIndicator(.visible)
        .task {
            await load()
        }
        .onDisappear {
            // シートを閉じた後も音声だけ鳴り続けないよう止め、他アプリの音声再開を通知してセッションを返す
            if case .playable(let player) = state {
                player.pause()
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }

    /// 動画を読み出し、再生できれば再生を始める。初回表示と「もう一度試す」から呼ぶ
    private func load() async {
        let loadedState = await loadVideoAnswerReplayState(videoAssetIdentifier: videoAssetIdentifier)
        // iCloud からのダウンロード中にシートを閉じると .task はキャンセルされるが、Photos への要求は
        // キャンセルを監視せず完了まで進む。閉じた後に再生を始めると onDisappear で止められず音声だけが流れるため、
        // 読み込み後・再生前にキャンセルを確認して打ち切る
        guard !Task.isCancelled else { return }
        state = loadedState
        if case .playable(let player) = loadedState {
            // 既定の ambient カテゴリではサイレントスイッチ ON の端末で音声が出ず、朝の自分の声を聞き返せないため、
            // 写真アプリの動画再生と同じく playback カテゴリで再生する。失敗しても映像の再生は妨げない
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
        }
    }

    /// 再生できない理由の表示 (削除済み・権限なし・読み込み失敗)
    private func unavailableText(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: 14, weight: .light))
            .tracking(0.42)
            .foregroundStyle(Color.warmWhite.opacity(0.45))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .accessibilityIdentifier("answer_video_unavailable_text")
    }
}

/// sheet(item:) で再生対象の動画を渡すための Identifiable ラッパー
struct VideoAnswerReplayTarget: Identifiable {
    /// 再生する動画の PHAsset localIdentifier
    let videoAssetIdentifier: String
    var id: String { videoAssetIdentifier }
}

/// 動画回答の再生画面の状態
enum VideoAnswerReplayState {
    /// 写真ライブラリから動画を読み出し中
    case loading
    /// 再生できる
    case playable(AVPlayer)
    /// 写真ライブラリの権限が無く読み出せない (動画回答の後にユーザーが設定で取り消した等)
    case photoLibraryDenied
    /// 権限はあるが動画が見つからない (写真アプリでユーザーが削除した等)
    case notFound
    /// 動画は存在するが読み込めなかった (iCloud 写真で端末から退避された動画のオフライン時や一時的なエラー)。再試行できる
    case loadFailed
}

/// 写真ライブラリの権限状態で、保存済みの回答動画を読み出せるかを判定する純粋関数。
/// limited (一部の写真のみ選択) でもアプリ自身が保存した資産は読み出せるため許可として扱う
func isPhotoLibraryReadableForVideoAnswer(photoLibraryStatus: PHAuthorizationStatus) -> Bool {
    photoLibraryStatus == .authorized || photoLibraryStatus == .limited
}

/// 保存済みの回答動画を再生できる状態にして返す。
/// 権限のリクエストは決定済みならダイアログを出さず現在の状態を返すため、何度呼んでも安全 (冪等)
func loadVideoAnswerReplayState(videoAssetIdentifier: String) async -> VideoAnswerReplayState {
    _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    guard isPhotoLibraryReadableForVideoAnswer(photoLibraryStatus: PHPhotoLibrary.authorizationStatus(for: .readWrite)) else {
        return .photoLibraryDenied
    }
    // 「動画が無い (削除済み)」と「動画はあるが読み込めない (一時的な失敗)」を分け、後者だけ再試行に誘導する
    guard let asset = fetchVideoAnswerAsset(videoAssetIdentifier: videoAssetIdentifier) else {
        return .notFound
    }
    guard let playerItem = await requestVideoAnswerPlayerItem(asset: asset) else {
        return .loadFailed
    }
    return .playable(AVPlayer(playerItem: playerItem))
}

/// 写真ライブラリから回答動画の PHAsset を引く。写真アプリで削除済みなど、見つからない時は nil を返す
func fetchVideoAnswerAsset(videoAssetIdentifier: String) -> PHAsset? {
    PHAsset.fetchAssets(withLocalIdentifiers: [videoAssetIdentifier], options: nil).firstObject
}

/// 回答動画の AVPlayerItem を取得する。取得に失敗した時は nil を返す。
/// 文字起こし (VideoAnswerTranscriber) と違い、iCloud 写真で端末から退避された動画も見返せるようダウンロードを許可する
func requestVideoAnswerPlayerItem(asset: PHAsset) async -> AVPlayerItem? {
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = true
    let canResume = makeResumeOnceGate()
    return await withCheckedContinuation { (continuation: CheckedContinuation<AVPlayerItem?, Never>) in
        PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
            guard canResume() else { return }
            continuation.resume(returning: playerItem)
        }
    }
}
