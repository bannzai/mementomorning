import Foundation
import Photos

/// 動画回答を格納するアプリ専用アルバムの名前。
/// 検索 (find) と作成 (create) で同じ名前を突き合わせて冪等にするため、
/// 端末の言語設定で変わらないプロダクト名そのままの固定文字列にする (ローカライズしない)
let videoAnswerAlbumTitle = "Memento Morning"

/// 動画回答の写真ライブラリ保存で起きるエラー
enum VideoAnswerPhotoLibraryError: Error {
    /// 動画の資産 (PHAsset) の作成リクエストを組み立てられなかった (ファイル形式が資産として不正など)
    case assetCreationRequestFailed
    /// 保存は成功したが、保存した資産の localIdentifier を取得できなかった
    case assetIdentifierMissing
}

/// 録画済みの動画ファイルを写真ライブラリへ保存し、保存した動画の PHAsset localIdentifier を返す。
/// readWrite が許可されている時はアプリ専用アルバム「Memento Morning」を検索または作成して格納する。
/// limited (一部の写真のみ選択) の時はアルバムの作成・検索ができないため、アルバムなしで保存だけ行う。
/// アルバムは名前の一致で使い回すため何度呼んでも 1 つに保たれる (資産の追加は録画のたびに新しい動画が増えるのが期待動作)
func saveVideoAnswerToPhotoLibrary(fileURL: URL) async throws -> String {
    let album: PHAssetCollection?
    if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized {
        album = try await fetchOrCreateVideoAnswerAlbum()
    } else {
        album = nil
    }

    var assetIdentifier: String?
    try await PHPhotoLibrary.shared().performChanges {
        guard let creationRequest = PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: fileURL) else {
            return
        }
        assetIdentifier = creationRequest.placeholderForCreatedAsset?.localIdentifier
        if let album,
           let placeholder = creationRequest.placeholderForCreatedAsset,
           let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) {
            albumChangeRequest.addAssets([placeholder] as NSArray)
        }
    }
    guard let assetIdentifier else {
        // creationRequest が nil のまま performChanges が成功した場合もここに落ちる
        throw VideoAnswerPhotoLibraryError.assetIdentifierMissing
    }
    return assetIdentifier
}

/// アプリ専用アルバム「Memento Morning」を検索し、無ければ作成して返す (名前の一致で使い回す冪等な find-or-create)
private func fetchOrCreateVideoAnswerAlbum() async throws -> PHAssetCollection {
    let fetchOptions = PHFetchOptions()
    fetchOptions.predicate = NSPredicate(format: "localizedTitle == %@", videoAnswerAlbumTitle)
    if let album = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: fetchOptions).firstObject {
        return album
    }

    var albumIdentifier: String?
    try await PHPhotoLibrary.shared().performChanges {
        albumIdentifier = PHAssetCollectionChangeRequest
            .creationRequestForAssetCollection(withTitle: videoAnswerAlbumTitle)
            .placeholderForCreatedAssetCollection.localIdentifier
    }
    guard let albumIdentifier,
          let album = PHAssetCollection.fetchAssetCollections(
              withLocalIdentifiers: [albumIdentifier],
              options: nil
          ).firstObject else {
        throw VideoAnswerPhotoLibraryError.assetIdentifierMissing
    }
    return album
}
