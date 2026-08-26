import Foundation
import StoreKit

/// リリースビルドで開発者メニューを解放するか (TestFlight 配布判定の結果) のプロセスローカルな状態。
/// UserDefaults へ永続化すると、TestFlight で true を保存したまま App Store 版へ更新した直後の起動で
/// 非同期の再判定が完了するまで解放が残ってしまうため、プロセスごとに必ず false から始め、
/// refreshDeveloperMenuUnlocked() が検証済みの .sandbox を確認した時だけ true にする (PR #129 レビュー指摘)。
/// 書き込みは refreshDeveloperMenuUnlocked (MainActor) 経由に限られ直列化されている。
/// 読み取りは任意のコンテキストから同期参照するため nonisolated(unsafe) にしている (Bool の読み取り競合は実害なし)
private nonisolated(unsafe) var developerMenuUnlockedInProcess = false

/// 進行中・完了済みの配布判定タスク (プロセス内で共有)。
/// 同時呼び出し (RootView の task と StopAlarmIntent の停止経路) がそれぞれ AppTransaction を取得して
/// 逆順で書き戻すと、検証成功の true を一時的な取得失敗の false が後から上書きするレースがあるため、
/// 1 つのタスクを共有して判定と書き込みを 1 系統にする (PR #136 レビュー指摘)。
/// 判定失敗 (nil) はキャッシュせず、次の呼び出しで再判定する (配布環境はプロセス内で変わらないため成功はキャッシュしてよい)。
/// id は失敗時の破棄で自分のタスクだけを消すための識別子 (Task は struct で同一性比較ができない)
@MainActor private var developerMenuUnlockTask: (id: UUID, task: Task<Bool?, Never>)?

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
/// AppTransaction の取得・検証に失敗した時は解放しない側 (false のまま) へ倒し、判定はキャッシュせず次の呼び出しで再試行する。
/// 同時呼び出しは developerMenuUnlockTask を共有して 1 回の判定にまとめ、
/// 成功後に別系統の失敗が false を書き戻すレースを塞ぐ (PR #136 レビュー指摘)
@MainActor
func refreshDeveloperMenuUnlocked() async {
    let entry = developerMenuUnlockTask ?? (id: UUID(), task: Task {
        switch try? await AppTransaction.shared {
        case .verified(let appTransaction):
            return shouldUnlockDeveloperMenu(environment: appTransaction.environment)
        case .unverified, nil:
            return nil
        }
    })
    developerMenuUnlockTask = entry
    guard let unlocked = await entry.task.value else {
        // 失敗したタスクを共有し続けると以後ずっと再判定されないため破棄する。
        // await 中の reentrancy で別の呼び出しが新しいタスクを入れ直していることがあるため、
        // id を比べて自分の失敗タスクが残っている時だけ消す (新タスクを巻き添えにしない。PR #136 レビュー指摘)。
        // 判定成功前しか失敗は起きない (成功済みタスクは再利用される) ので、ここで false が true を上書きすることもない
        if developerMenuUnlockTask?.id == entry.id {
            developerMenuUnlockTask = nil
        }
        return
    }
    developerMenuUnlockedInProcess = unlocked
}
