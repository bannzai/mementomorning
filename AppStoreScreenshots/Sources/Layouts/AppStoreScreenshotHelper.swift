import SwiftUI

// MARK: - レイアウトコンテナ

/// 訴求軸 ink (静かな世界観そのままの墨背景) のレイアウトコンテナ。
/// 上部にキャッチコピー、下部にデバイスフレーム付きのモック画面を置く。
/// デザイントークン (design_handoff_memento_morning/README.md) に従い、影・彩度の高い色・バッジは使わない
struct AppStoreScreenshotInkLayout<Content: View>: View {
    /// メインのキャッチコピー
    let title: Text
    /// サブコピー (二次テキスト 55% 白)
    let subtitle: LocalizedStringResource
    /// 下部に夜明けグラデーション (オンボーディングの地平線表現) を敷くかどうか。
    /// アクセントは各画面 1 箇所までのため、モック画面側で夜明け色を使うページでは敷かない
    var showsDawnHorizon = false
    /// デバイスフレーム内に表示するモック画面
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.ink

            if showsDawnHorizon {
                dawnHorizon
            }

            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    title
                        .font(.system(size: 34, weight: .light))
                        .tracking(1.7)
                        .lineSpacing(12)
                        .foregroundStyle(Color.warmWhite)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.system(size: 15, weight: .light))
                        .tracking(0.9)
                        .lineSpacing(6)
                        .foregroundStyle(Color.warmWhite.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 70)
                .padding(.horizontal, 36)

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

    /// オンボーディングと同じ夜明けグラデーション + 地平線 1pt ライン (デザイン handoff 11 参照)
    private var dawnHorizon: some View {
        VStack(spacing: 0) {
            Spacer()
            LinearGradient(
                colors: [Color.dawn.opacity(0), Color.dawn.opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.dawn.opacity(0), Color.dawn.opacity(0.7), Color.dawn.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
            }
        }
    }
}

// MARK: - デバイスフレーム

/// モック画面を実機解像度 (393×852pt) でレンダリングし、縮小表示する。
/// フレーム内のレイアウトが縮小率に依存せず本番画面と一致するようにするための仕組み
/// (取り込み元: bannzai/Focus の同名 struct)
struct ScreenshotContentImage<Content: View>: View {
    /// レンダリングする論理サイズ。iPhone の実機 pt サイズを渡す
    let size: CGSize
    /// レンダリング対象のモック画面
    let content: Content

    /// @ViewBuilder でモック画面を受け取るために明示的に init を定義する
    init(size: CGSize, @ViewBuilder content: () -> Content) {
        self.size = size
        self.content = content()
    }

    var body: some View {
        renderImage()
    }

    /// ImageRenderer で実サイズ描画した画像を返す。scale 3.0 は実機 (@3x) と同じ解像度で文字を滲ませないため
    @MainActor
    private func renderImage() -> some View {
        let renderer = ImageRenderer(
            content: content.frame(width: size.width, height: size.height)
        )
        renderer.scale = 3.0
        return Group {
            if let uiImage = renderer.uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}

/// デバイスフレームのベゼル表現。影・画像アセットは使わず、ヘアラインのストロークだけで表現する
struct IPhoneFrameOverlay: View {
    /// ストロークの色。既定値は暗背景バリアント (ink / dawn) 用のヘアライン。
    /// 明背景バリアント (washi) は墨のヘアラインを渡して背景とのコントラストを保つ
    var strokeColor = Color.warmWhite.opacity(0.18)

    var body: some View {
        RoundedRectangle(cornerRadius: 36)
            .stroke(strokeColor, lineWidth: 3)
    }
}

// MARK: - モック画面の共通部品

/// モック画面の pill ボタン風表示。静的レンダリング (ImageRenderer) 用に Button ではなく Text で表現し、
/// 見た目は本番の PrimaryPillButtonStyle / SecondaryPillButtonStyle に合わせる
struct MockPillLabel: View {
    /// pill 内のラベル
    let label: Text
    /// true なら primary (温白地に墨文字)、false なら secondary (ヘアライン枠のみ)
    var isPrimary = true

    var body: some View {
        label
            .font(.system(size: 15, weight: .regular))
            .tracking(1.5)
            .foregroundStyle(isPrimary ? Color.ink : Color.warmWhite.opacity(0.75))
            .frame(maxWidth: .infinity)
            .padding(.vertical, isPrimary ? 17 : 15)
            .background {
                if isPrimary {
                    Capsule().fill(Color.warmWhite)
                } else {
                    Capsule().stroke(Color.warmWhite.opacity(0.25), lineWidth: 1)
                }
            }
    }
}
