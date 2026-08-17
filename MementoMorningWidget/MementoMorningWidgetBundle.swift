import SwiftUI
import WidgetKit

/// MementoMorningWidget Extension のエントリポイント
@main
struct MementoMorningWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayAnswerWidget()
        TodayAnswerLiveActivityWidget()
        AlarmLiveActivityWidget()
    }
}
