import SwiftUI

/// 訴求軸 kohaku (25〜30 枚目)。アクセントの夜明け色 (dawn) をベタ地に使い、墨の太字見出しを
/// 中央に置く構成。競合 5 Minute Journal の「単色の温かい地 × 大きな黒見出し」型
/// (2026-08-20 に iTunes API のスクリーンショットで実測) をデザイントークンで再現し、
/// ストア一覧で暗色・白地のどちらの競合とも並ばない色にする。
/// キャッチコピーは ink (1〜6 枚目) と同一にし、見せ方の差だけを比較できるようにする。
/// スクリーンショット番号とバリアントの対応は scripts/generate_screenshots/appstore_screenshot_env.sh の get_variant_name が正

/// 訴求軸 kohaku のレイアウトコンテナ
struct AppStoreScreenshotKohakuLayout<Content: View>: View {
    /// メインのキャッチコピー
    let title: Text
    /// サブコピー (二次テキスト 72% 墨)
    let subtitle: LocalizedStringResource
    /// デバイスフレーム内に表示するモック画面
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.dawn

            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    title
                        // 36pt + 横 padding 28 で 1 行あたり約 10 文字 (washi の実測に基づく組み合わせ) を保つ
                        .font(.system(size: 36, weight: .bold))
                        .tracking(0.5)
                        .lineSpacing(10)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.system(size: 16, weight: .regular))
                        .tracking(0.5)
                        .lineSpacing(6)
                        .foregroundStyle(Color.ink.opacity(0.72))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 64)
                .padding(.horizontal, 28)

                Spacer()

                // デバイスは傾けず正面・垂直に配置する (appstore-screenshot-builder skill の共通デザイン原則)。
                // 下端はフレームごと画面外に切り、モック画面の下部ボタン省略と整合させる
                ScreenshotContentImage(size: CGSize(width: 393, height: 852)) {
                    content()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 36))
                .overlay(IPhoneFrameOverlay(strokeColor: Color.ink.opacity(0.35)))
                .aspectRatio(9.0 / 19.5, contentMode: .fit)
                .padding(.horizontal, 46)
                .offset(y: 56)
            }
        }
        .ignoresSafeArea()
    }
}

/// App Store スクリーンショット 25 枚目 - kohaku - 朝の問い (コアコンセプト)
struct AppStoreScreenshot25Page: View {
    var body: some View {
        AppStoreScreenshotKohakuLayout(
            // ja: 毎朝、死を想ってから
            //
            // 起きる。
            title: Text("Memento mori, every morning."),
            // ja: 問いに答えて、アラームを止める。
            subtitle: "Answer the question to stop the alarm."
        ) {
            MockMorningQuestionScreen()
        }
    }
}

/// AppStoreScreenshot25Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot25Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot25Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 26 枚目 - kohaku - 追撃アラーム (答えるまで止まらない)
struct AppStoreScreenshot26Page: View {
    var body: some View {
        AppStoreScreenshotKohakuLayout(
            // ja: 答えるまで、鳴り止まない。
            title: Text("It keeps ringing until you answer."),
            // ja: 回答が成立するまで、追撃アラームが戻ってきます。
            subtitle: "Follow-up alarms return until this morning's answer exists."
        ) {
            MockHomeScreen()
        }
    }
}

/// AppStoreScreenshot26Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot26Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot26Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 27 枚目 - kohaku - ジャーナル (回答の蓄積)
struct AppStoreScreenshot27Page: View {
    var body: some View {
        AppStoreScreenshotKohakuLayout(
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

/// AppStoreScreenshot27Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot27Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot27Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 28 枚目 - kohaku - カレンダー (答えた朝の蓄積)
struct AppStoreScreenshot28Page: View {
    var body: some View {
        AppStoreScreenshotKohakuLayout(
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

/// AppStoreScreenshot28Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot28Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot28Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 29 枚目 - kohaku - 夜の振り返り (ループを閉じる)
struct AppStoreScreenshot29Page: View {
    var body: some View {
        AppStoreScreenshotKohakuLayout(
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

/// AppStoreScreenshot29Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot29Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot29Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 30 枚目 - kohaku - 七つの朝 (節目)
struct AppStoreScreenshot30Page: View {
    var body: some View {
        AppStoreScreenshotKohakuLayout(
            // ja: 七日目、七つの答えと再会する。
            title: Text("On day seven, meet your seven answers."),
            // ja: 静かな節目が、続く理由になります。
            subtitle: "Quiet milestones keep you coming back."
        ) {
            MockSevenMorningsScreen()
        }
    }
}

/// AppStoreScreenshot30Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot30Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot30Page().environment(\.colorScheme, .dark)
    }
}
