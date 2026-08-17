import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// AlarmKit のアラーム (カウントダウン・鳴動) のロック画面 / Dynamic Island 表示。
/// Widget Extension を持つアプリでは AlarmAttributes の ActivityConfiguration をここで提供する
/// (AlarmMetadata 型は両ターゲット必須。MementoMorningAlarmMetadata のコメント参照)。
/// アラーム鳴動時はシステムが AlarmPresentation.Alert を優先描画するため、カスタム View は最小限にする
/// (参照実装 bannzai/Alarmy の AlarmLiveActivityWidget で確認済みの挙動)
struct AlarmLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<MementoMorningAlarmMetadata>.self) { context in
            VStack(spacing: 8) {
                if let title = context.attributes.metadata?.title {
                    Text(title)
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Color.warmWhite)
                        .multilineTextAlignment(.center)
                }
                if case .countdown(let countdown) = context.state.mode {
                    Text(countdown.fireDate, style: .timer)
                        .font(.system(size: 27, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(Color.warmWhite)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 24)
            .activityBackgroundTint(Color.ink)
            .activitySystemActionForegroundColor(Color.warmWhite)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    if let title = context.attributes.metadata?.title {
                        Text(title)
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(Color.warmWhite)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
            } compactLeading: {
                Circle()
                    .fill(Color.dawn)
                    .frame(width: 6, height: 6)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Circle()
                    .fill(Color.dawn)
                    .frame(width: 6, height: 6)
            }
            .keylineTint(context.attributes.tintColor)
        }
    }
}
