import SwiftUI

/// 訴求軸 kumo (19〜24 枚目)。明るい雲色の地に墨の太字見出しを左揃えで置く editorial 構成。
/// 競合 stoic. の「明背景 × 左揃え太字見出し」型 (2026-08-20 に iTunes API のスクリーンショットで実測) を
/// デザイントークンで再現する (ブランドラベルは PR #89 のフィードバックで不要と判断し置かない)。
/// キャッチコピーは ink (1〜6 枚目) と同一にし、見せ方の差だけを比較できるようにする。
/// スクリーンショット番号とバリアントの対応は scripts/generate_screenshots/appstore_screenshot_env.sh の get_variant_name が正

/// 訴求軸 kumo のレイアウトコンテナ
struct AppStoreScreenshotKumoLayout<Content: View>: View {
    /// メインのキャッチコピー
    let title: Text
    /// サブコピー (二次テキスト 60% 墨)
    let subtitle: LocalizedStringResource
    /// デバイスフレーム内に表示するモック画面
    @ViewBuilder let content: () -> Content

    /// 背景の雲色。warmWhite より一段明るいニュートラルな灰白
    private let cloud = Color(red: 0xF2 / 255, green: 0xF1 / 255, blue: 0xED / 255)

    var body: some View {
        ZStack {
            cloud

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    title
                        // 38pt + 横 padding 30 で 1 行あたり約 10 文字 (washi の実測に基づく組み合わせ) を保つ
                        .font(.system(size: 38, weight: .bold))
                        .tracking(0.3)
                        .lineSpacing(8)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.system(size: 16, weight: .regular))
                        .tracking(0.5)
                        .lineSpacing(6)
                        .foregroundStyle(Color.ink.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 56)
                .padding(.horizontal, 30)

                Spacer()

                // デバイスは傾けず正面・垂直に配置する (appstore-screenshot-builder skill の共通デザイン原則)。
                // 下端はフレームごと画面外に切り、モック画面の下部ボタン省略と整合させる
                ScreenshotContentImage(size: CGSize(width: 393, height: 852)) {
                    content()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 36))
                .overlay(IPhoneFrameOverlay(strokeColor: Color.ink.opacity(0.2)))
                .aspectRatio(9.0 / 19.5, contentMode: .fit)
                .padding(.horizontal, 46)
                .offset(y: 56)
            }
        }
        .ignoresSafeArea()
    }
}

/// App Store スクリーンショット 19 枚目 - kumo - 朝の問い (コアコンセプト)
struct AppStoreScreenshot19Page: View {
    var body: some View {
        AppStoreScreenshotKumoLayout(
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

/// AppStoreScreenshot19Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot19Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot19Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 20 枚目 - kumo - 追撃アラーム (答えるまで止まらない)
struct AppStoreScreenshot20Page: View {
    var body: some View {
        AppStoreScreenshotKumoLayout(
            // ja: 答えるまで、鳴り止まない。
            title: Text("It keeps ringing until you answer."),
            // ja: 回答が成立するまで、追撃アラームが戻ってきます。
            subtitle: "Follow-up alarms return until this morning's answer exists."
        ) {
            MockHomeScreen()
        }
    }
}

/// AppStoreScreenshot20Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot20Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot20Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 21 枚目 - kumo - ジャーナル (回答の蓄積)
struct AppStoreScreenshot21Page: View {
    var body: some View {
        AppStoreScreenshotKumoLayout(
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

/// AppStoreScreenshot21Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot21Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot21Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 22 枚目 - kumo - 点 (粒の蓄積)
struct AppStoreScreenshot22Page: View {
    var body: some View {
        AppStoreScreenshotKumoLayout(
            // ja: 答えた朝が、
            //
            // 点として残る。
            title: Text("Answered mornings remain as dots."),
            // ja: 点は、いつかつながる。
            subtitle: "The dots will connect."
        ) {
            MockDotsScreen()
        }
    }
}

/// AppStoreScreenshot22Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot22Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot22Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 23 枚目 - kumo - 夜の振り返り (ループを閉じる)
struct AppStoreScreenshot23Page: View {
    var body: some View {
        AppStoreScreenshotKumoLayout(
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

/// AppStoreScreenshot23Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot23Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot23Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 24 枚目 - kumo - 七つの朝 (節目)
struct AppStoreScreenshot24Page: View {
    var body: some View {
        AppStoreScreenshotKumoLayout(
            // ja: 七日目、七つの答えと再会する。
            title: Text("On day seven, meet your seven answers."),
            // ja: 静かな節目が、続く理由になります。
            subtitle: "Quiet milestones keep you coming back."
        ) {
            MockSevenMorningsScreen()
        }
    }
}

/// AppStoreScreenshot24Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot24Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot24Page().environment(\.colorScheme, .dark)
    }
}
