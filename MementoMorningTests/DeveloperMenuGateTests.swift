import StoreKit
import XCTest
@testable import MementoMorning

/// 開発者メニューの解放判定 (shouldUnlockDeveloperMenu) のテスト。
/// TestFlight 配布 (.sandbox) だけを解放し、App Store 配布 (.production) では解放しないことを固定する (issue #128)
final class DeveloperMenuGateTests: XCTestCase {
    func testSandboxUnlocksDeveloperMenu() {
        // TestFlight 配布は AppTransaction.environment が .sandbox になる
        XCTAssertTrue(shouldUnlockDeveloperMenu(environment: .sandbox))
    }

    func testProductionDoesNotUnlockDeveloperMenu() {
        // App Store 配布 (.production) で解放すると本番ユーザーに検証用フラグが効いてしまう
        XCTAssertFalse(shouldUnlockDeveloperMenu(environment: .production))
    }

    func testXcodeDoesNotUnlockDeveloperMenu() {
        // Xcode からの直接実行は DEBUG ビルドの常時解放 (isDeveloperMenuUnlocked) で足りるため対象外
        XCTAssertFalse(shouldUnlockDeveloperMenu(environment: .xcode))
    }
}
