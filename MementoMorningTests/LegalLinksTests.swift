import XCTest
@testable import MementoMorning

/// 法務リンク (LegalLinks) とバージョン表示 (appVersionText) のテスト。
/// URL は設定画面と Paywall の両方から参照されるため、scheme / host / path が意図どおりであることを固定する (issue #83)
final class LegalLinksTests: XCTestCase {
    func testTermsURL() {
        XCTAssertEqual(LegalLinks.terms.scheme, "https")
        XCTAssertEqual(LegalLinks.terms.host, "bannzai.github.io")
        XCTAssertEqual(LegalLinks.terms.lastPathComponent, "Terms-ja")
    }

    func testPrivacyPolicyURL() {
        XCTAssertEqual(LegalLinks.privacyPolicy.scheme, "https")
        XCTAssertEqual(LegalLinks.privacyPolicy.host, "bannzai.github.io")
        XCTAssertEqual(LegalLinks.privacyPolicy.lastPathComponent, "PrivacyPolicy-ja")
    }

    func testSpecifiedCommercialTransactionActURL() {
        XCTAssertEqual(LegalLinks.specifiedCommercialTransactionAct.scheme, "https")
        XCTAssertEqual(LegalLinks.specifiedCommercialTransactionAct.host, "bannzai.github.io")
        XCTAssertEqual(LegalLinks.specifiedCommercialTransactionAct.lastPathComponent, "SpecifiedCommercialTransactionAct-ja")
    }

    func testContactURLIsMailto() {
        XCTAssertEqual(LegalLinks.contact.scheme, "mailto")
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
