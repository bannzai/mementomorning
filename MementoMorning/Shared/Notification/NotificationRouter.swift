import Foundation
import Observation
import UserNotifications

/// 通知タップから開く画面の提示状態。View から観測する
@Observable
@MainActor
final class NotificationRouter {
    /// 共有インスタンス
    static let shared = NotificationRouter()

    /// 夜の振り返り画面を提示中かどうか
    var isNightReflectionPresented = false
}

/// UNUserNotificationCenter のデリゲート。受け取った通知を NotificationRouter の状態へ変換する
///
/// UNUserNotificationCenter.delegate は弱参照のため、シングルトンとして強参照を保持する。
/// @Observable な NotificationRouter とは同居させない (Observation のマクロと NSObject 継承・nonisolated なデリゲートメソッドの isolation が噛み合わないため、状態と受け口を分ける)
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// 共有インスタンス
    static let shared = NotificationDelegate()

    /// フォアグラウンドでも通知を表示する。シミュレータでの発火確認は画面表示で判定するため、バナーを抑制しない
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// 通知タップを受け取り、夜リマインドであれば夜の振り返り画面を開く
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.content.categoryIdentifier == NightReminder.categoryIdentifier else {
            return
        }
        await MainActor.run {
            NotificationRouter.shared.isNightReflectionPresented = true
        }
    }
}
