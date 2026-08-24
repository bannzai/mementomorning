import Foundation
import StoreKit

/// リリースビルドで開発者メニューを解放するか (TestFlight 配布判定の結果) のプロセスローカルな状態。
/// UserDefaults へ永続化すると、TestFlight で true を保存したまま App Store 版へ更新した直後の起動で
/// 非同期の再判定が完了するまで解放が残ってしまうため、プロセスごとに必ず false から始め、
/// refreshDeveloperMenuUnlocked() が検証済みの .sandbox を確認した時だけ true にする (PR #129 レビュー指摘)。
/// 書き込みは起動時の refresh のみで以降は読み取り専用の Bool のため、nonisolated(unsafe) にしている
private nonisolated(unsafe) var developerMenuUnlockedInProcess = false

/// 開発者メニュー (DebugMenuPage) の導線と検証用フラグ (プレミアム強制・疑似録画) を使えるかどうか。
/// DEBUG ビルドでは常に true。リリースビルドはプロセス開始時点では常に false で、
/// 起動時の refreshDeveloperMenuUnlocked() が TestFlight 配布と判定した時だけ true になり、
/// App Store 配布では false のまま (issue #128。TestFlight は App Store と同一の Release バイナリのため
/// `#if DEBUG` では提供できず、実行時判定でゲートする)。
/// 検証用フラグの効果もこの判定を通し、本番ユーザーの UserDefaults が外部から書き換えられても効かないようにする
var isDeveloperMenuUnlocked: Bool {
    #if DEBUG
    return true
    #else
    return developerMenuUnlockedInProcess
    #endif
}

/// App Store 署名の配布環境から開発者メニューを解放するかを判定する。
/// TestFlight 配布は .sandbox、App Store 配布は .production になる。
/// Xcode からの直接実行 (.xcode) は DEBUG ビルドの常時解放で足りるため対象にしない (解放しない側へ倒す)。
/// 純粋関数であり、同じ入力に対して常に同じ出力を返す (冪等)
func shouldUnlockDeveloperMenu(environment: AppStore.Environment) -> Bool {
    environment == .sandbox
}

/// TestFlight 配布かどうかを AppTransaction で判定して isDeveloperMenuUnlocked の状態を更新する。
/// 状態はプロセスローカルのため起動のたびに false から始まり、この関数が呼ばれるまで解放されない。
/// AppTransaction の取得・検証に失敗した時は解放しない側 (false) へ倒す
func refreshDeveloperMenuUnlocked() async {
    switch try? await AppTransaction.shared {
    case .verified(let appTransaction):
        developerMenuUnlockedInProcess = shouldUnlockDeveloperMenu(environment: appTransaction.environment)
    case .unverified, nil:
        developerMenuUnlockedInProcess = false
    }
}
