import WidgetKit
import SwiftUI

/// MementoMorningWidget Extension のエントリポイント
@main
struct MementoMorningWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayAnswerWidget()
    }
}
