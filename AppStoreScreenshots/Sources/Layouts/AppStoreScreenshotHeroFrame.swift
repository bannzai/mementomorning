import SwiftUI

/// 1 枚目候補 hero (37〜42 枚目)。「朝に、起きる時に使うアプリ」であることを 1 枚目で伝えるための
/// クリエイティブ案の比較バンド。washi / kumo / kohaku (PR #89 のフィードバックで選好) をベースに、
/// アラーム鳴動モック・特大時刻・夜明けの帯を組み合わせる。
/// 採用が決まったら、その案を対象バリアントの 1 枚目 (7 / 19 / 25 枚目) に反映して本番の一式にする。
/// スクリーンショット番号とバリアントの対応は scripts/generate_screenshots/appstore_screenshot_env.sh の get_variant_name が正

/// App Store スクリーンショット 37 枚目 - hero - washi 地 × アラーム鳴動モック (目覚まし訴求コピー)
struct AppStoreScreenshot37Page: View {
    var body: some View {
        AppStoreScreenshotWashiLayout(
            // ja: 毎朝、ひとつの問いで起こす目覚まし。
            title: Text("A morning alarm that asks one question."),
            // ja: 答えると、アラームは止まります。
            subtitle: "Answer it, and the alarm stops."
        ) {
            MockAlarmRingingScreen()
        }
    }
}

/// AppStoreScreenshot37Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot37Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot37Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 38 枚目 - hero - kumo 地 × アラーム鳴動モック (起床コピー)
struct AppStoreScreenshot38Page: View {
    var body: some View {
        AppStoreScreenshotKumoLayout(
            // ja: 問いで、目を覚ます。
            title: Text("Wake up to the question."),
            // ja: 問いに答えて、アラームを止める。
            subtitle: "Answer the question to stop the alarm."
        ) {
            MockAlarmRingingScreen()
        }
    }
}

/// AppStoreScreenshot38Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot38Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot38Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 39 枚目 - hero - kohaku 地 × アラーム鳴動モック (既存コピー)
struct AppStoreScreenshot39Page: View {
    var body: some View {
        AppStoreScreenshotKohakuLayout(
            // ja: 毎朝、死を想ってから
            //
            // 起きる。
            title: Text("Memento mori, every morning."),
            // ja: 答えると、アラームは止まります。
            subtitle: "Answer it, and the alarm stops."
        ) {
            MockAlarmRingingScreen()
        }
    }
}

/// AppStoreScreenshot39Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot39Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot39Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 40 枚目 - hero - washi 地 × 特大時刻ヘッダー (時刻そのものを主役にする案)
struct AppStoreScreenshot40Page: View {
    var body: some View {
        ZStack {
            Color.warmWhite

            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    // 特大時刻。ローカライズ対象外の視覚要素のため verbatim
                    Text(verbatim: "5:50")
                        .font(.system(size: 120, weight: .thin))
                        .foregroundStyle(Color.ink)
                    // ja: 明日の朝、問いが鳴る。
                    Text("Tomorrow morning, the question rings.")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(0.5)
                        .lineSpacing(8)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                    // ja: 問いに答えて、アラームを止める。
                    Text("Answer the question to stop the alarm.")
                        .font(.system(size: 16, weight: .regular))
                        .tracking(0.5)
                        .lineSpacing(6)
                        .foregroundStyle(Color.ink.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 34)
                .padding(.horizontal, 28)

                Spacer()

                // デバイスは傾けず正面・垂直に配置する (appstore-screenshot-builder skill の共通デザイン原則)。
                // 下端はフレームごと画面外に切り、モック画面の下部ボタン省略と整合させる
                ScreenshotContentImage(size: CGSize(width: 393, height: 852)) {
                    MockMorningQuestionScreen()
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

/// AppStoreScreenshot40Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot40Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot40Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 41 枚目 - hero - kumo 地 × 夜明けの帯 (夜明けの空気で朝を伝える案)
struct AppStoreScreenshot41Page: View {
    /// 背景の雲色 (kumo と同じ)
    private let cloud = Color(red: 0xF2 / 255, green: 0xF1 / 255, blue: 0xED / 255)

    var body: some View {
        ZStack {
            cloud

            // 下半分に夜明けのグラデーション。明背景でも地平線の空気を出す
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [Color.dawn.opacity(0), Color.dawn.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 700)
            }

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    // ja: 夜明けは、問いとともに。
                    Text("Dawn comes with a question.")
                        .font(.system(size: 38, weight: .bold))
                        .tracking(0.3)
                        .lineSpacing(8)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.8)
                    // ja: 問いに答えて、アラームを止める。
                    Text("Answer the question to stop the alarm.")
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
                    MockAlarmRingingScreen()
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

/// AppStoreScreenshot41Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot41Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot41Page().environment(\.colorScheme, .dark)
    }
}

/// App Store スクリーンショット 42 枚目 - hero - kohaku 地 × ホームモック (今夜セットする文脈で朝を伝える案)
struct AppStoreScreenshot42Page: View {
    var body: some View {
        AppStoreScreenshotKohakuLayout(
            // ja: 今夜セットすれば、朝が変わる。
            title: Text("Tonight, set the alarm. Morning changes."),
            // ja: 問いが、明日のあなたを待っています。
            subtitle: "The question waits for tomorrow's you."
        ) {
            MockHomeScreen()
        }
    }
}

/// AppStoreScreenshot42Page の Preview。UITest (SnapshotUITest wrapper) の撮影対象
struct AppStoreScreenshot42Page_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreScreenshot42Page().environment(\.colorScheme, .dark)
    }
}
