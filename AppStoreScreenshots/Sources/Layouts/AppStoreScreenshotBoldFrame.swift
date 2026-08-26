import SwiftUI

/// 訴求軸 bold (31〜36 枚目)。墨背景のまま見出しを最大級の極太・左揃えにし、
/// テキストの占有率を上げる構成。競合 Alarmy の「画面上部を占める極太コピー」型
/// (2026-08-20 に iTunes API のスクリーンショットで実測) を、彩度の高い色を使わずに
/// デザイントークンで再現する。上部に夜明けの微光を淡く敷き、黒一色の沈みを避ける。
/// キャッチコピーは ink (1〜6 枚目) と同一にし、見せ方の差だけを比較できるようにする。
/// スクリーンショット番号とバリアントの対応は scripts/generate_screenshots/appstore_screenshot_env.sh の get_variant_name が正

/// 訴求軸 bold のレイアウトコンテナ
struct AppStoreScreenshotBoldLayout<Content: View>: View {
    /// メインのキャッチコピー
    let title: Text
    /// サブコピー (二次テキスト 80% 白)
    let subtitle: LocalizedStringResource
    /// デバイスフレーム内に表示するモック画面
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.ink

            // 上部に夜明けの微光を淡く敷く (アクセントは 1 箇所のみ)
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.dawn.opacity(0.18), Color.dawn.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 420)
                Spacer()
            }

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    title
                        // 38pt + 横 padding 24 で 1 行あたり約 10 文字 (washi の実測に基づく組み合わせ) を保つ
                        .font(.system(size: 38, weight: .heavy))
                        .lineSpacing(8)
                        .foregroundStyle(Color.warmWhite)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.system(size: 18, weight: .medium))
                        .lineSpacing(6)
                        .foregroundStyle(Color.warmWhite.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 52)
                .padding(.horizontal, 24)

                Spacer()

                // デバイスは傾けず正面・垂直に配置する (appstore-screenshot-builder skill の共通デザイン原則)。
                // 下端はフレームごと画面外に切り、モック画面の下部ボタン省略と整合させる
                ScreenshotContentImage(size: CGSize(width: 393, height: 852)) {
                    content()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 36))
                .overlay(IPhoneFrameOverlay(strokeColor: Color.warmWhite.opacity(0.18)))
                .aspectRatio(9.0 / 19.5, contentMode: .fit)
                .padding(.horizontal, 46)
                .offset(y: 56)
            }
        }
        .ignoresSafeArea()
    }
}

/// App Store スクリーンショット 31 枚目 - bold - 朝の問い (コアコンセプト)
struct AppStoreScreenshot31Page: View {
    var body: some View {
        AppStoreScreenshotBoldLayout(
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

/// AppStoreScreenshot31Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot31Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot31Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 32 枚目 - bold - 追撃アラーム (答えるまで止まらない)
struct AppStoreScreenshot32Page: View {
    var body: some View {
        AppStoreScreenshotBoldLayout(
            // ja: 答えるまで、鳴り止まない。
            title: Text("It keeps ringing until you answer."),
            // ja: 回答が成立するまで、追撃アラームが戻ってきます。
            subtitle: "Follow-up alarms return until this morning's answer exists."
        ) {
            MockHomeScreen()
        }
    }
}

/// AppStoreScreenshot32Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot32Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot32Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 33 枚目 - bold - ジャーナル (回答の蓄積)
struct AppStoreScreenshot33Page: View {
    var body: some View {
        AppStoreScreenshotBoldLayout(
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

/// AppStoreScreenshot33Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot33Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot33Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 34 枚目 - bold - カレンダー (答えた朝の蓄積)
struct AppStoreScreenshot34Page: View {
    var body: some View {
        AppStoreScreenshotBoldLayout(
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

/// AppStoreScreenshot34Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot34Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot34Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 35 枚目 - bold - 夜の振り返り (ループを閉じる)
struct AppStoreScreenshot35Page: View {
    var body: some View {
        AppStoreScreenshotBoldLayout(
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

/// AppStoreScreenshot35Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot35Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot35Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 36 枚目 - bold - 七つの朝 (節目)
struct AppStoreScreenshot36Page: View {
    var body: some View {
        AppStoreScreenshotBoldLayout(
            // ja: 七日目、七つの答えと再会する。
            title: Text("On day seven, meet your seven answers."),
            // ja: 静かな節目が、続く理由になります。
            subtitle: "Quiet milestones keep you coming back."
        ) {
            MockSevenMorningsScreen()
        }
    }
}

/// AppStoreScreenshot36Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot36Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot36Page().environment(\.colorScheme, .dark)
    }
}
