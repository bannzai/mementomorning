import SwiftUI

/// 訴求軸 washi (7〜12 枚目)。温白地に墨文字の反転構成で、ストア一覧で並んだ時の視認性を上げる。
/// 競合調査 (appstore-screenshot-result/research/2026-08-16) で確認した stoic. の
/// 「明背景 × 太字黒見出し × 暗いデバイス画面」構成を、Memento Morning のデザイントークンで再現する。
/// キャッチコピーは ink (1〜6 枚目) と同一にし、視認性の差だけを比較できるようにする。
/// スクリーンショット番号とバリアントの対応は scripts/generate_screenshots/appstore_screenshot_env.sh の get_variant_name が正

/// 訴求軸 washi のレイアウトコンテナ。
/// warmWhite 地に ink の太字見出しを置き、墨背景のモック画面を強コントラストで浮かせる
struct AppStoreScreenshotWashiLayout<Content: View>: View {
    /// メインのキャッチコピー
    let title: Text
    /// サブコピー (二次テキスト 60% 墨)
    let subtitle: LocalizedStringResource
    /// デバイスフレーム内に表示するモック画面
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.warmWhite

            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    title
                        // ink バリアント (34pt light) がサムネイルで消える懸念への対応で太字化する。
                        // サイズは 36pt: 横 padding 28 との組で 1 行あたり約 10 文字になり、
                        // ink (34pt / padding 36) と同じ折り返し位置を保つ (40pt では ja が語中で折り返された実測による)
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
                        .foregroundStyle(Color.ink.opacity(0.6))
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
                .overlay(IPhoneFrameOverlay(strokeColor: Color.ink.opacity(0.25)))
                .aspectRatio(9.0 / 19.5, contentMode: .fit)
                .padding(.horizontal, 46)
                .offset(y: 56)
            }
        }
        .ignoresSafeArea()
    }
}

/// App Store スクリーンショット 7 枚目 - washi - アラーム鳴動 (朝・起きる時に使うアプリであることを 1 枚目で伝える。
/// hero 案の比較 (PR #89) で washi × 鳴動モック × 既存コピーを採用)
struct AppStoreScreenshot7Page: View {
    var body: some View {
        AppStoreScreenshotWashiLayout(
            // ja: 毎朝、死を想ってから
            //
            // 起きる。
            title: Text("Memento mori, every morning."),
            // ja: 問いに答えて、アラームを止める。
            subtitle: "Answer the question to stop the alarm."
        ) {
            MockAlarmRingingScreen()
        }
    }
}

/// AppStoreScreenshot7Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot7Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot7Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 8 枚目 - washi - 追撃アラーム (答えるまで止まらない)
struct AppStoreScreenshot8Page: View {
    var body: some View {
        AppStoreScreenshotWashiLayout(
            // ja: 答えるまで、鳴り止まない。
            title: Text("It keeps ringing until you answer."),
            // ja: 回答が成立するまで、追撃アラームが戻ってきます。
            subtitle: "Follow-up alarms return until this morning's answer exists."
        ) {
            MockHomeScreen()
        }
    }
}

/// AppStoreScreenshot8Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot8Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot8Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 9 枚目 - washi - ジャーナル (回答の蓄積)
struct AppStoreScreenshot9Page: View {
    var body: some View {
        AppStoreScreenshotWashiLayout(
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

/// AppStoreScreenshot9Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot9Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot9Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 10 枚目 - washi - 点 (粒の蓄積)
struct AppStoreScreenshot10Page: View {
    var body: some View {
        AppStoreScreenshotWashiLayout(
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

/// AppStoreScreenshot10Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot10Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot10Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 11 枚目 - washi - 夜の振り返り (ループを閉じる)
struct AppStoreScreenshot11Page: View {
    var body: some View {
        AppStoreScreenshotWashiLayout(
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

/// AppStoreScreenshot11Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot11Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot11Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 12 枚目 - washi - 七つの朝 (節目)
struct AppStoreScreenshot12Page: View {
    var body: some View {
        AppStoreScreenshotWashiLayout(
            // ja: 七日目、七つの答えと再会する。
            title: Text("On day seven, meet your seven answers."),
            // ja: 静かな節目が、続く理由になります。
            subtitle: "Quiet milestones keep you coming back."
        ) {
            MockSevenMorningsScreen()
        }
    }
}

/// AppStoreScreenshot12Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot12Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot12Page().environment(\.colorScheme, .dark)
    }
}
