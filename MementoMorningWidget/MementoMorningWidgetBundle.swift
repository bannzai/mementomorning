import SwiftUI
import WidgetKit

/// MementoMorningWidget Extension のエントリポイント
@main
struct MementoMorningWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayAnswerLiveActivityWidget()
        AlarmLiveActivityWidget()
    }
}
