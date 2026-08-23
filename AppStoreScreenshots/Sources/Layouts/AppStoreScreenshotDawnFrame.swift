import SwiftUI

/// 訴求軸 dawn (13〜18 枚目)。墨背景を保ったまま視認性を上げる改良案。
/// 見出しを太字化し、夜明けグラデーション (dawn) を ink バリアントより強めて
/// 「暗いが黒一色ではない」画面にする (競合調査レポートの改善提案 3)。
/// キャッチコピーは ink (1〜6 枚目) と同一にし、視認性の差だけを比較できるようにする。
/// スクリーンショット番号とバリアントの対応は scripts/generate_screenshots/appstore_screenshot_env.sh の get_variant_name が正

/// 訴求軸 dawn のレイアウトコンテナ。
/// 墨背景 + 全ページ共通の夜明けグラデーションに、warmWhite の太字見出しを置く
struct AppStoreScreenshotDawnLayout<Content: View>: View {
    /// メインのキャッチコピー
    let title: Text
    /// サブコピー (二次テキスト 70% 白)
    let subtitle: LocalizedStringResource
    /// デバイスフレーム内に表示するモック画面
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.ink

            dawnHorizon

            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    title
                        // ink バリアント (34pt light) がサムネイルで消える懸念への対応で太字化する。
                        // サイズは 36pt: 横 padding 28 との組で 1 行あたり約 10 文字になり、
                        // ink (34pt / padding 36) と同じ折り返し位置を保つ (40pt では ja が語中で折り返された実測による)
                        .font(.system(size: 36, weight: .bold))
                        .tracking(0.5)
                        .lineSpacing(10)
                        .foregroundStyle(Color.warmWhite)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.system(size: 16, weight: .regular))
                        .tracking(0.5)
                        .lineSpacing(6)
                        .foregroundStyle(Color.warmWhite.opacity(0.7))
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
                .overlay(IPhoneFrameOverlay())
                .aspectRatio(9.0 / 19.5, contentMode: .fit)
                .padding(.horizontal, 46)
                .offset(y: 56)
            }
        }
        .ignoresSafeArea()
    }

    /// ink バリアントの dawnHorizon (高さ 300 / 透過 0.22) を強めた夜明けグラデーション。
    /// 高さ 560 / 透過 0.45 は「一覧サムネイルでも暗一色に見えない」ことを目視で確認して決めた値
    private var dawnHorizon: some View {
        VStack(spacing: 0) {
            Spacer()
            LinearGradient(
                colors: [Color.dawn.opacity(0), Color.dawn.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 560)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.dawn.opacity(0), Color.dawn.opacity(0.9), Color.dawn.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
            }
        }
    }
}

/// App Store スクリーンショット 13 枚目 - dawn - 朝の問い (コアコンセプト)
struct AppStoreScreenshot13Page: View {
    var body: some View {
        AppStoreScreenshotDawnLayout(
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

/// AppStoreScreenshot13Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot13Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot13Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 14 枚目 - dawn - 追撃アラーム (答えるまで止まらない)
struct AppStoreScreenshot14Page: View {
    var body: some View {
        AppStoreScreenshotDawnLayout(
            // ja: 答えるまで、鳴り止まない。
            title: Text("It keeps ringing until you answer."),
            // ja: 回答が成立するまで、追撃アラームが戻ってきます。
            subtitle: "Follow-up alarms return until this morning's answer exists."
        ) {
            MockHomeScreen()
        }
    }
}

/// AppStoreScreenshot14Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot14Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot14Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 15 枚目 - dawn - ジャーナル (回答の蓄積)
struct AppStoreScreenshot15Page: View {
    var body: some View {
        AppStoreScreenshotDawnLayout(
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

/// AppStoreScreenshot15Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot15Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot15Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 16 枚目 - dawn - 点 (粒の蓄積)
struct AppStoreScreenshot16Page: View {
    var body: some View {
        AppStoreScreenshotDawnLayout(
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

/// AppStoreScreenshot16Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot16Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot16Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 17 枚目 - dawn - 夜の振り返り (ループを閉じる)
struct AppStoreScreenshot17Page: View {
    var body: some View {
        AppStoreScreenshotDawnLayout(
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

/// AppStoreScreenshot17Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot17Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot17Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 18 枚目 - dawn - 七つの朝 (節目)
struct AppStoreScreenshot18Page: View {
    var body: some View {
        AppStoreScreenshotDawnLayout(
            // ja: 七日目、七つの答えと再会する。
            title: Text("On day seven, meet your seven answers."),
            // ja: 静かな節目が、続く理由になります。
            subtitle: "Quiet milestones keep you coming back."
        ) {
            MockSevenMorningsScreen()
        }
    }
}

/// AppStoreScreenshot18Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot18Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot18Page().environment(\.colorScheme, .dark)
    }
}
