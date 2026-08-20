import XCTest
@testable import MementoMorning

/// 法務リンク (LegalLinks) とバージョン表示 (appVersionText) のテスト。
/// URL は設定画面と Paywall の両方から参照されるため、scheme / host / path が意図どおりであることを固定する (issue #83)。
/// 利用規約とプライバシーポリシーは表示言語による ja / en の出し分けを検証する (issue #90)
final class LegalLinksTests: XCTestCase {
    func testTermsURLForJapanese() {
        let url = LegalLinks.terms(displayLanguageCode: "ja")
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "bannzai.github.io")
        XCTAssertEqual(url.lastPathComponent, "Terms-ja")
    }

    func testTermsURLForNonJapanese() {
        XCTAssertEqual(LegalLinks.terms(displayLanguageCode: "en").lastPathComponent, "Terms-en")
        XCTAssertEqual(LegalLinks.terms(displayLanguageCode: "de").lastPathComponent, "Terms-en")
    }

    func testPrivacyPolicyURLForJapanese() {
        let url = LegalLinks.privacyPolicy(displayLanguageCode: "ja")
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "bannzai.github.io")
        XCTAssertEqual(url.lastPathComponent, "PrivacyPolicy-ja")
    }

    func testPrivacyPolicyURLForNonJapanese() {
        XCTAssertEqual(LegalLinks.privacyPolicy(displayLanguageCode: "en").lastPathComponent, "PrivacyPolicy-en")
        XCTAssertEqual(LegalLinks.privacyPolicy(displayLanguageCode: "zh-Hans").lastPathComponent, "PrivacyPolicy-en")
    }

    /// 引数なしの terms / privacyPolicy が表示言語に応じた ja / en のどちらかを返すことを検証する。
    /// テスト実行環境の表示言語は固定できないため、具体的な言語版までは固定しない
    func testDefaultURLsResolveToSupportedLanguage() {
        XCTAssertTrue(["Terms-ja", "Terms-en"].contains(LegalLinks.terms.lastPathComponent))
        XCTAssertTrue(["PrivacyPolicy-ja", "PrivacyPolicy-en"].contains(LegalLinks.privacyPolicy.lastPathComponent))
    }

    func testSpecifiedCommercialTransactionActURL() {
        XCTAssertEqual(LegalLinks.specifiedCommercialTransactionAct.scheme, "https")
        XCTAssertEqual(LegalLinks.specifiedCommercialTransactionAct.host, "bannzai.github.io")
        XCTAssertEqual(LegalLinks.specifiedCommercialTransactionAct.lastPathComponent, "SpecifiedCommercialTransactionAct-ja")
    }

    func testContactURLIsMailto() {
        XCTAssertEqual(LegalLinks.contact.absoluteString, "mailto:bannzai.app@gmail.com")
    }

    func testAppVersionTextCombinesVersionAndBuild() {
        XCTAssertEqual(
            appVersionText(infoDictionary: ["CFBundleShortVersionString": "1.2", "CFBundleVersion": "34"]),
            "1.2 (34)"
        )
    }

    func testAppVersionTextFallsBackWhenKeysAreMissing() {
        XCTAssertEqual(appVersionText(infoDictionary: [:]), "- (-)")
        XCTAssertEqual(appVersionText(infoDictionary: nil), "- (-)")
    }
}
