import SwiftUI

/// 訴求軸 ink (1〜6 枚目)。静かな世界観そのままの墨背景に、コア体験を朝 → 蓄積 → 夜 → 節目の順で並べる。
/// スクリーンショット番号とバリアントの対応は scripts/generate_screenshots/appstore_screenshot_env.sh の get_variant_name が正

/// App Store スクリーンショット 1 枚目 - ink - 朝の問い (コアコンセプト)
struct AppStoreScreenshot1Page: View {
    var body: some View {
        AppStoreScreenshotInkLayout(
            // ja: 毎朝、死を想ってから
            //
            // 起きる。
            title: Text("Memento mori, every morning."),
            // ja: 問いに答えて、アラームを止める。
            subtitle: "Answer the question to stop the alarm.",
            showsDawnHorizon: true
        ) {
            MockMorningQuestionScreen()
        }
    }
}

/// AppStoreScreenshot1Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot1Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot1Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 2 枚目 - ink - 追撃アラーム (答えるまで止まらない)
struct AppStoreScreenshot2Page: View {
    var body: some View {
        AppStoreScreenshotInkLayout(
            // ja: 答えるまで、鳴り止まない。
            title: Text("It keeps ringing until you answer."),
            // ja: 回答が成立するまで、追撃アラームが戻ってきます。
            subtitle: "Follow-up alarms return until this morning's answer exists."
        ) {
            MockHomeScreen()
        }
    }
}

/// AppStoreScreenshot2Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot2Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot2Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 3 枚目 - ink - ジャーナル (回答の蓄積)
struct AppStoreScreenshot3Page: View {
    var body: some View {
        AppStoreScreenshotInkLayout(
            // ja: 毎朝の答えが、
            //
            // 人生の記録になる。
            title: Text("Every morning's answer becomes a journal of your life."),
            // ja: 回答は、ひと朝ずつここに集まっていきます。
            subtitle: "Your answers gather here, one morning at a time."
        ) {
            MockJournalScreen()
        }
    }
}

/// AppStoreScreenshot3Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot3Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot3Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 4 枚目 - ink - カレンダー (答えた朝の蓄積)
struct AppStoreScreenshot4Page: View {
    var body: some View {
        AppStoreScreenshotInkLayout(
            // ja: 答えた朝が、
            //
            // 点として残る。
            title: Text("Answered mornings remain as dots."),
            // ja: 点は、いつかつながる。
            subtitle: "The dots will connect."
        ) {
            MockCalendarScreen()
        }
    }
}

/// AppStoreScreenshot4Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot4Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot4Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 5 枚目 - ink - 夜の振り返り (ループを閉じる)
struct AppStoreScreenshot5Page: View {
    var body: some View {
        AppStoreScreenshotInkLayout(
            // ja: 夜、朝の自分と
            //
            // 答え合わせ。
            title: Text("At night, check in with your morning self."),
            // ja: 「守れてますか?」のリマインドでループを閉じます。
            subtitle: "A quiet reminder asks: are you keeping it?"
        ) {
            MockNightReflectionScreen()
        }
    }
}

/// AppStoreScreenshot5Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot5Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot5Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 6 枚目 - ink - 七つの朝 (節目)
struct AppStoreScreenshot6Page: View {
    var body: some View {
        AppStoreScreenshotInkLayout(
            // ja: 七日目、七つの答えと再会する。
            title: Text("On day seven, meet your seven answers."),
            // ja: 静かな節目が、続く理由になります。
            subtitle: "Quiet milestones keep you coming back."
        ) {
            MockSevenMorningsScreen()
        }
    }
}

/// AppStoreScreenshot6Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot6Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot6Page().environment(\.colorScheme, .dark)
    }
}
