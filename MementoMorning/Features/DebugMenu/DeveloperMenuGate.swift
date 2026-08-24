import Foundation
import StoreKit

extension String {
    /// リリースビルドで開発者メニューを解放するか (TestFlight 配布判定の結果) をキャッシュする UserDefaults キー。
    /// AppTransaction の取得は非同期のため、起動時に refreshDeveloperMenuUnlocked() が判定してここへ保存し、
    /// 参照側 (isDeveloperMenuUnlocked) は同期的にキャッシュを読む
    static let developerMenuUnlocked = "developerMenuUnlocked"
}

/// 開発者メニュー (DebugMenuPage) の導線と検証用フラグ (プレミアム強制・疑似録画) を使えるかどうか。
/// DEBUG ビルドでは常に true。リリースビルドは TestFlight 配布と判定された時だけ true になり、
/// App Store 配布では false のまま (issue #128。TestFlight は App Store と同一の Release バイナリのため
/// `#if DEBUG` では提供できず、実行時判定でゲートする)。
/// 検証用フラグの効果もこの判定を通し、本番ユーザーの UserDefaults が外部から書き換えられても効かないようにする
var isDeveloperMenuUnlocked: Bool {
    #if DEBUG
    return true
    #else
    return UserDefaults.standard.bool(forKey: .developerMenuUnlocked)
    #endif
}

/// App Store 署名の配布環境から開発者メニューを解放するかを判定する。
/// TestFlight 配布は .sandbox、App Store 配布は .production になる。
/// Xcode からの直接実行 (.xcode) は DEBUG ビルドの常時解放で足りるため対象にしない (解放しない側へ倒す)。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func shouldUnlockDeveloperMenu(environment: AppStore.Environment) -> Bool {
    environment == .sandbox
}

/// TestFlight 配布かどうかを AppTransaction で判定して isDeveloperMenuUnlocked のキャッシュを更新する。
/// TestFlight から App Store 版へ更新した後の起動で解放状態を持ち越さないよう、起動のたびに呼び直す (冪等)。
/// AppTransaction の取得・検証に失敗した時は解放しない側 (false) へ倒す
func refreshDeveloperMenuUnlocked() async {
    let unlocked: Bool
    switch try? await AppTransaction.shared {
    case .verified(let appTransaction):
        unlocked = shouldUnlockDeveloperMenu(environment: appTransaction.environment)
    case .unverified, nil:
        unlocked = false
    }
    UserDefaults.standard.set(unlocked, forKey: .developerMenuUnlocked)
}
