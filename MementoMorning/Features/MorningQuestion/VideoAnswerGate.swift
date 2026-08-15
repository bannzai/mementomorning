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
/// 写真ライブラリはアプリ専用アルバム「Memento Morning」の作成・検索に読み取りが必要なため、
/// addOnly ではなく readWrite でリクエストする (addOnly ではアルバムの作成・検索ができない。
/// ref: https://developer.apple.com/forums/thread/661196 )
func requestVideoAnswerPermissions() async -> Bool {
    _ = await AVCaptureDevice.requestAccess(for: .video)
    _ = await AVCaptureDevice.requestAccess(for: .audio)
    _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    return isVideoAnswerPermitted(
        cameraStatus: AVCaptureDevice.authorizationStatus(for: .video),
        microphoneStatus: AVCaptureDevice.authorizationStatus(for: .audio),
        photoLibraryStatus: PHPhotoLibrary.authorizationStatus(for: .readWrite)
    )
}
