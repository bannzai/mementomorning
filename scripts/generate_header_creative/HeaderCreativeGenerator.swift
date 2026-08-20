import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// App Store creative assets (product page header / search results) を SwiftUI で描画して
// PNG 出力するジェネレータ。macOS の swiftc でコンパイルして実行する (実行方法は同ディレクトリの
// generate_header_creative.sh)。配色は AppStoreScreenshots/Sources/DesignTokens.swift を
// 同時にコンパイルして共有する。
//
// canvas と Art Safe Area の値は Apple 公式テンプレート PSD の実測
// (appstore-header-creative skill の fetch_template_spec.sh、2026-08-17 取得) が根拠。
// キーコンテンツ (問い + 一粒の点) は Art Safe Area 内に収める。

/// 生成対象のアセット種別。canvas サイズと Art Safe Area は Apple 公式テンプレート PSD の実測値
enum CreativeAssetType: String, CaseIterable {
    case productPageHeader = "product_page_header"
    case searchResults = "search_results"

    /// テンプレート PSD の作業領域サイズ (px)
    var canvasSize: CGSize {
        switch self {
        case .productPageHeader: CGSize(width: 3840, height: 1646)
        case .searchResults: CGSize(width: 3840, height: 2560)
        }
    }

    /// キーコンテンツを収める Art Safe Area (px)。テンプレート PSD の同名レイヤーの実測座標
    var artSafeArea: CGRect {
        switch self {
        case .productPageHeader: CGRect(x: 1097, y: 493, width: 2743 - 1097, height: 1154 - 493)
        case .searchResults: CGRect(x: 836, y: 765, width: 3004 - 836, height: 1795 - 765)
        }
    }
}

/// 生成する言語。App Store のローカライズ言語 (ja / en-US) に対応する
enum CreativeAssetLanguage: String, CaseIterable {
    case ja
    case enUS = "en-US"

    /// 問いの本文。SSOT は MementoMorning/Localizable.xcstrings の
    /// "If today were your last day, what would you want to do?" (ja 訳: 今日死ぬとしたら何をやりたいですか？)。
    /// 折り返し位置を制御するため明示的な改行を入れて転記する
    var questionText: String {
        switch self {
        case .ja: "今日死ぬとしたら\n何をやりたいですか？"
        case .enUS: "If today were your last day,\nwhat would you want to do?"
        }
    }
}

/// creative asset の 1 枚分のビュー。
/// 墨背景 + 光る一粒の点 (アプリアイコンと同モチーフ) + 問い + 夜明けの微光 (スクショと同モチーフ) で構成し、
/// スクリーンショット基盤 (AppStoreScreenshots) と配色・タイポグラフィを揃える
struct CreativeAssetView: View {
    /// 生成対象のアセット種別
    let assetType: CreativeAssetType
    /// 生成する言語
    let language: CreativeAssetLanguage
    /// Art Safe Area を赤枠で重ねる検証用フラグ (成果物では false)
    let showsSafeAreaGuide: Bool

    var body: some View {
        ZStack {
            Color.ink

            dawnHorizon

            VStack(spacing: assetType.canvasSize.height * 0.05) {
                glowingDot
                Text(verbatim: language.questionText)
                    // 光る点 (アプリアイコン) と同じ「静かな」トーンを保つため、スクショ ink バリアント
                    // (34pt light) と同じ light ウェイトを使う。表示スケールが大きい (canvas 3840px は
                    // 実機で約 1/3 に縮小表示) ため、細字でも視認性は落ちない
                    .font(.system(size: questionFontSize, weight: .light))
                    .tracking(questionFontSize * 0.04)
                    .lineSpacing(questionFontSize * 0.45)
                    .foregroundStyle(Color.warmWhite)
                    .multilineTextAlignment(.center)
            }
            // キーコンテンツを Art Safe Area の中央に置く (canvas 中央と Safe Area 中央は一致する)

            if showsSafeAreaGuide {
                safeAreaGuide
            }
        }
        .frame(width: assetType.canvasSize.width, height: assetType.canvasSize.height)
    }

    /// 問いの文字サイズ (px)。各言語の最長行が Art Safe Area の幅 (header 1646px / search 2168px) に
    /// 収まるように選び、check_header_asset.sh 後の目視確認で検証した値
    private var questionFontSize: CGFloat {
        switch (assetType, language) {
        case (.productPageHeader, .ja): 150
        case (.productPageHeader, .enUS): 110
        case (.searchResults, .ja): 180
        case (.searchResults, .enUS): 140
        }
    }

    /// アプリアイコンと同じ「光る一粒の点」。warmWhite の核と柔らかいグローで構成する
    private var glowingDot: some View {
        // 核の直径は問いの文字サイズの半分: 点はモチーフであって主役は問いのため、文字より小さく保つ
        let coreDiameter = questionFontSize * 0.5
        return Circle()
            .fill(Color.warmWhite)
            .frame(width: coreDiameter, height: coreDiameter)
            .background(
                RadialGradient(
                    colors: [Color.warmWhite.opacity(0.35), Color.warmWhite.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: coreDiameter * 3.2
                )
                .frame(width: coreDiameter * 6.4, height: coreDiameter * 6.4)
            )
    }

    /// スクショの dawnHorizon と同モチーフの夜明けグラデーション。
    /// 高さは canvas の 28%: 地平線 (グラデーション上端) が Art Safe Area 下端 (header 1154 / search 1795) より
    /// 下に来る最大値で、問いのテキストに地平線が重ならない。透過 0.35 は問いの可読性を優先した控えめな値
    private var dawnHorizon: some View {
        VStack(spacing: 0) {
            Spacer()
            LinearGradient(
                colors: [Color.dawn.opacity(0), Color.dawn.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: assetType.canvasSize.height * 0.28)
            .overlay(alignment: .top) {
                // 地平線の微光。スクショの 1pt 線を canvas スケール (約 4 倍) に合わせて 4px にする
                LinearGradient(
                    colors: [Color.dawn.opacity(0), Color.dawn.opacity(0.9), Color.dawn.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 4)
            }
        }
    }

    /// Art Safe Area の検証用赤枠
    private var safeAreaGuide: some View {
        Rectangle()
            .stroke(Color.red, lineWidth: 4)
            .frame(width: assetType.artSafeArea.width, height: assetType.artSafeArea.height)
            .position(x: assetType.artSafeArea.midX, y: assetType.artSafeArea.midY)
    }
}

/// CGImage を不透明 (alpha なし) の PNG として書き出す。書き出しに失敗した場合は false を返す。
/// ImageRenderer の出力は alpha 付きだが、App Store creative assets は透過の可否が未公表のため
/// (appstore-header-creative skill references/asset-spec.md「未確定事項」)、拒否リスクを避けて alpha を落とす
func writePNG(cgImage: CGImage, url: URL) -> Bool {
    guard let opaqueContext = CGContext(
        data: nil,
        width: cgImage.width,
        height: cgImage.height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        return false
    }
    opaqueContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    guard let opaqueImage = opaqueContext.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        return false
    }
    CGImageDestinationAddImage(destination, opaqueImage, nil)
    return CGImageDestinationFinalize(destination)
}

/// 全アセット (種別 x 言語) を出力ディレクトリへ PNG 出力するエントリポイント。
/// 同名ファイルへの上書き出力のため再実行しても結果は変わらない (冪等)
@main
struct HeaderCreativeGenerator {
    @MainActor
    static func main() {
        let arguments = CommandLine.arguments
        // フラグ形の値 (--safe-area-guide 等) を出力ディレクトリとして誤解釈しないよう拒否する
        guard arguments.count >= 2, !arguments[1].hasPrefix("--") else {
            FileHandle.standardError.write(Data("usage: \(arguments[0]) <出力ディレクトリ> [--safe-area-guide]\n".utf8))
            exit(2)
        }
        let outputDirectoryURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let showsSafeAreaGuide = arguments.contains("--safe-area-guide")
        try? FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        for assetType in CreativeAssetType.allCases {
            for language in CreativeAssetLanguage.allCases {
                let renderer = ImageRenderer(content: CreativeAssetView(
                    assetType: assetType,
                    language: language,
                    showsSafeAreaGuide: showsSafeAreaGuide
                ))
                // canvas 実寸 (px) をポイント単位で指定しているため、scale 1 で 1pt = 1px として出力する
                renderer.scale = 1
                guard let cgImage = renderer.cgImage else {
                    FileHandle.standardError.write(Data("error: \(assetType.rawValue) \(language.rawValue) の描画に失敗した\n".utf8))
                    exit(1)
                }
                let outputFileURL = outputDirectoryURL.appendingPathComponent("\(assetType.rawValue)_\(language.rawValue).png")
                guard writePNG(cgImage: cgImage, url: outputFileURL) else {
                    FileHandle.standardError.write(Data("error: \(outputFileURL.path) の書き出しに失敗した\n".utf8))
                    exit(1)
                }
                print("generated: \(outputFileURL.path) (\(cgImage.width)x\(cgImage.height))")
            }
        }
    }
}
