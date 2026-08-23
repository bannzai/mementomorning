import Foundation
import SwiftData

/// 永続化層のシングルトン。App Groups の共有コンテナに保存し、将来の Widget と共有する
@MainActor
struct PersistenceController {
    /// アプリで使用する全ての永続化モデルタイプ。新しいモデルを追加する際はここに追加する。
    /// Widget Extension の TimelineProvider (nonisolated) からも参照するため、schema / configuration と共に MainActor 隔離を外す
    nonisolated static let types: [any PersistentModel.Type] = [
        MorningAnswer.self,
        AlarmSetting.self,
        ScheduledAlarm.self,
        NightReminderSetting.self,
    ]

    /// 全モデルから構築したスキーマ
    nonisolated static let schema = Schema(types)

    /// 本番用の永続化設定。App Groups コンテナに保存する
    nonisolated static let configuration = ModelConfiguration(
        "MementoMorning",
        schema: schema,
        groupContainer: .identifier("group.com.bannzai.MementoMorning"),
        cloudKitDatabase: .none
    )

    /// 共有インスタンス
    static let shared = PersistenceController()

    /// SwiftData の ModelContainer
    let container: ModelContainer

    /// PersistenceController は環境に応じて container の設定を切り替えるため、明示的に init を定義する
    init() {
        do {
            if isUnitTest || isUITest || isPreview {
                container = try ModelContainer(
                    for: Self.schema,
                    configurations: [.init("MementoMorning", schema: Self.schema, isStoredInMemoryOnly: true)]
                )
            } else {
                container = try ModelContainer(for: Self.schema, configurations: Self.configuration)
            }
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}
