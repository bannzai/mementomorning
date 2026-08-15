import AlarmKit
import UserNotifications
import XCTest

@testable import MementoMorning

/// needsPermissionSettingsGuidance のテスト。
/// 明示的に拒否された許可がある場合だけ設定アプリへの誘導を表示する
final class OnboardingPermissionTests: XCTestCase {
    func testNoGuidanceWhenBothNotDetermined() {
        XCTAssertFalse(
            needsPermissionSettingsGuidance(
                alarmAuthorizationState: .notDetermined,
                notificationAuthorizationStatus: .notDetermined
            )
        )
    }

    func testNoGuidanceWhenBothAuthorized() {
        XCTAssertFalse(
            needsPermissionSettingsGuidance(
                alarmAuthorizationState: .authorized,
                notificationAuthorizationStatus: .authorized
            )
        )
    }

    func testGuidanceWhenAlarmDenied() {
        XCTAssertTrue(
            needsPermissionSettingsGuidance(
                alarmAuthorizationState: .denied,
                notificationAuthorizationStatus: .authorized
            )
        )
    }

    func testGuidanceWhenNotificationDenied() {
        XCTAssertTrue(
            needsPermissionSettingsGuidance(
                alarmAuthorizationState: .authorized,
                notificationAuthorizationStatus: .denied
            )
        )
    }
}
