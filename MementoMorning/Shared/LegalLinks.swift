import Foundation

/// 利用規約・プライバシーポリシー等の外部リンク (docs/ を GitHub Pages で配信している)。
/// 設定画面と Paywall の両方から参照するため 1 箇所にまとめる (issue #83)
enum LegalLinks {
    /// 利用規約
    static let terms = URL(string: "https://bannzai.github.io/mementomorning/Terms-ja")!
    /// プライバシーポリシー
    static let privacyPolicy = URL(string: "https://bannzai.github.io/mementomorning/PrivacyPolicy-ja")!
    /// 特定商取引法に基づく表記
    static let specifiedCommercialTransactionAct = URL(string: "https://bannzai.github.io/mementomorning/SpecifiedCommercialTransactionAct-ja")!
    /// 問い合わせ先 (メール)
    static let contact = URL(string: "mailto:bannzai.app@gmail.com")!
}

/// アプリのバージョン表示文字列 (例: "1.0 (1)")。CFBundleShortVersionString と CFBundleVersion を組み合わせる。
/// 設定画面の「情報」セクションで表示する (issue #83)
func appVersionText(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) -> String {
    let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    let build = infoDictionary?["CFBundleVersion"] as? String ?? "-"
    return "\(version) (\(build))"
}
