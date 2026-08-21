import AlarmKit
import SwiftUI

/// AlarmKit 操作を集約する Utility。
///
/// AlarmKit の制約 (.claude/rules/ios-alarmkit-constraints.md):
/// - iOS 26.0+ 専用。deployment target が 26.0 のため availability ガードは不要
/// - Info.plist に NSAlarmKitUsageDescription が必須。AlarmKit 固有の entitlement は不要
/// - アラームはアプリをバックグラウンド wake しない。再スケジュールは foreground でのみ可能
/// - サイレントモード・集中モードを標準で突破して鳴る
/// - ユーザーがアラームをスワイプ消去した場合、アプリ側で検知する方法がない (バックアップアラームで保険をかける)
/// - アラーム ID は UUID。cancelAll は存在しない。alarms を全列挙して個別 cancel(id:) する
/// - ID と自アプリのデータの対応付けは AlarmMetadata 準拠のカスタム型 (MementoMorningAlarmMetadata) に持たせる
/// - システムのアラーム UI の停止ボタンは消せない・差し替えられない。iOS 26.1 で AlarmPresentation.Alert の
///   stopButton は deprecated になり、停止 UI はシステム標準描画になった
/// - シミュレータでは sound を .default または省略にすると鳴らない癖がある。発火確認は画面表示で判定する
/// - 件数上限あり (AlarmError.maximumLimitReached が存在する)。無制限を前提にしない
enum AlarmKitManager {
    /// 認可状態を返す
    static var authorizationState: AlarmManager.AuthorizationState {
        AlarmManager.shared.authorizationState
    }

    /// 認可をリクエストする。Info.plist の NSAlarmKitUsageDescription が必須 (entitlement は不要)
    static func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        try await AlarmManager.shared.requestAuthorization()
    }

    /// 固定日時のアラームをスケジュールする
    static func schedule(id: UUID, fireDate: Date, title: LocalizedStringResource) async throws {
        let attributes = AlarmAttributes<MementoMorningAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert(title: title)),
            metadata: MementoMorningAlarmMetadata(title: String(localized: title)),
            // 静かな世界観に合わせて黒。彩度のあるアクセントカラーは使わない
            tintColor: Color.black
        )
        _ = try await AlarmManager.shared.schedule(
            id: id,
            configuration: .alarm(
                schedule: .fixed(fireDate),
                attributes: attributes,
                stopIntent: StopAlarmIntent(alarmID: id)
            )
        )
    }

    /// 発火画面の alert を作成する。
    /// stopButton を渡さない init は iOS 26.1 以降にしか存在しないため、
    /// deployment target (26.0) を満たす iOS 26.0 のみ stopButton 付きの init へフォールバックする
    /// (指定した stopButton は iOS 26.1 以降では使われず、停止 UI はシステム標準描画になる)
    private static func alert(title: LocalizedStringResource) -> AlarmPresentation.Alert {
        if #available(iOS 26.1, *) {
            return .init(title: title)
        } else {
            // ja: 止める
            return .init(title: title, stopButton: .init(text: "Stop", textColor: .white, systemImageName: "stop.circle"))
        }
    }

    /// 登録済みアラームを全キャンセルする (preservedAlarmIDs の ID は保護して残す)。
    /// AlarmKit に cancelAll は存在しないため、alarms を全列挙して個別 cancel(id:) する。
    /// 保護指定は未発火の追撃アラームを foreground 復帰の再スケジュールから守るために使う
    static func cancelAll(preservedAlarmIDs: Set<UUID> = []) throws {
        for alarm in try AlarmManager.shared.alarms where !preservedAlarmIDs.contains(alarm.id) {
            try AlarmManager.shared.cancel(id: alarm.id)
        }
    }

    /// OS 側に登録済みのアラームが残っているかを返す (preservedAlarmIDs の ID は残っていて正常なため数えない)。
    /// 一覧の取得自体に失敗した場合は「残っているかもしれない」として true を返す (fail-closed 用)
    static func hasRemainingAlarms(preservedAlarmIDs: Set<UUID> = []) -> Bool {
        guard let alarms = try? AlarmManager.shared.alarms else { return true }
        return alarms.contains { !preservedAlarmIDs.contains($0.id) }
    }

    /// 登録済みアラームを個別キャンセルする
    static func cancel(id: UUID) throws {
        try AlarmManager.shared.cancel(id: id)
    }

    /// 鳴動中アラームを停止する
    static func stop(id: UUID) throws {
        try AlarmManager.shared.stop(id: id)
    }
}
