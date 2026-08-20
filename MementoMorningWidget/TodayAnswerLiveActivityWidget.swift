import ActivityKit
import SwiftUI
import WidgetKit

/// ロック画面 / Dynamic Island に「今日の目標」(今日の回答) を表示する Live Activity (issue #45)。
/// 朝の回答が成立してから 1 日、問いへの答えを目に入る場所に残しておくための表示。
/// staleDate (翌日 0 時) を過ぎた stale 状態では、前日の回答を「今日の目標」として見せないよう
/// 本文の代わりに問いを表示する (アプリが起動されない限り Activity をコードから畳めないため、表示側で切り替える)
struct TodayAnswerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodayAnswerActivityAttributes.self) { context in
            TodayAnswerLockScreenView(text: context.state.text, isStale: context.isStale)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Group {
                        if context.isStale {
                            // ja: 今日死ぬとしたら何をやりたいですか？
                            Text("If today were your last day, what would you want to do?")
                        } else {
                            Text(context.state.text)
                        }
                    }
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Color.warmWhite)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                }
            } compactLeading: {
                // ゲーミフィケーションの記号を使わない世界観のため、compact / minimal は夜明け色の点だけにする
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
            .keylineTint(Color.dawn)
        }
    }
}

/// ロック画面の「今日の目標」表示。静かな世界観 (墨背景・温白の本文・夜明け色のキャプション) に合わせる
struct TodayAnswerLockScreenView: View {
    /// 今日の回答本文
    let text: String
    /// staleDate (翌日 0 時) を過ぎたかどうか。過ぎた後は前日の回答ではなく問いを表示する
    let isStale: Bool

    var body: some View {
        VStack(spacing: 10) {
            if isStale {
                // ja: 今日死ぬとしたら何をやりたいですか？
                Text("If today were your last day, what would you want to do?")
                    .font(.system(size: 17, weight: .light))
                    .lineSpacing(6)
                    .foregroundStyle(Color.warmWhite)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            } else {
                // ja: 今朝のことば
                Text("This morning's words")
                    .font(.system(size: 10))
                    .tracking(2.2)
                    .foregroundStyle(Color.dawn)
                Text(text)
                    .font(.system(size: 17, weight: .light))
                    .lineSpacing(6)
                    .foregroundStyle(Color.warmWhite)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 24)
        .activityBackgroundTint(Color.ink)
        .activitySystemActionForegroundColor(Color.warmWhite)
    }
}
