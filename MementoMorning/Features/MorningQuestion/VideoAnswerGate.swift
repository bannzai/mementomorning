import AVFoundation
import Photos

/// 動画回答 (インカメラ録画) を利用できる権限状態かを判定する純粋関数。
/// カメラとマイクは録画に、写真ライブラリは録画した動画の保存に必須のため、どれか 1 つでも欠けたら false
/// (受け入れ条件「カメラ/マイク/写真の権限拒否時にテキスト入力へフォールバックする」の判定に使う)。
/// 写真ライブラリの limited (一部の写真のみ選択) は、資産の追加は可能なため許可として扱う
/// (アルバムの作成・検索だけができない。保存側で limited をアルバムなし保存に分岐する)
func isVideoAnswerPermitted(
    cameraStatus: AVAuthorizationStatus,
    microphoneStatus: AVAuthorizationStatus,
    photoLibraryStatus: PHAuthorizationStatus
) -> Bool {
    cameraStatus == .authorized
        && microphoneStatus == .authorized
        && (photoLibraryStatus == .authorized || photoLibraryStatus == .limited)
}

/// 動画回答に必要な権限 (カメラ → マイク → 写真ライブラリの順) をリクエストし、すべて使える状態なら true を返す。
/// 決定済み (許可/拒否) の権限にシステムはダイアログを出さず現在の状態を返すため、何度呼んでも安全 (冪等)。
/// 拒否された時点で後続のリクエストを打ち切る。動画回答はどれか 1 つでも欠けたら成立せず、
/// 残りのダイアログを待つ間、画面には使えない録画ボタンだけが残るため (issue #50)。
/// 写真ライブラリはアプリ専用アルバム「Memento Morning」の作成・検索に読み取りが必要なため、
/// addOnly ではなく readWrite でリクエストする (addOnly ではアルバムの作成・検索ができない。
/// ref: https://developer.apple.com/forums/thread/661196 )
func requestVideoAnswerPermissions() async -> Bool {
    // 疑似録画モード (issue #52) では実撮影をしないため、カメラ・マイクの権限は要求も判定もしない。
    // 録画結果の保存先である写真ライブラリだけが必要
    if isDebugSimulateVideoAnswerEnabled {
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return photoLibraryStatus == .authorized || photoLibraryStatus == .limited
    }
    guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
    guard await AVCaptureDevice.requestAccess(for: .audio) else { return false }
    _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    return isVideoAnswerPermitted(
        cameraStatus: AVCaptureDevice.authorizationStatus(for: .video),
        microphoneStatus: AVCaptureDevice.authorizationStatus(for: .audio),
        photoLibraryStatus: PHPhotoLibrary.authorizationStatus(for: .readWrite)
    )
}
