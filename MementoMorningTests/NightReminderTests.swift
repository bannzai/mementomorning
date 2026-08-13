import XCTest
import UserNotifications
@testable import MementoMorning

/// 夜リマインドの通知リクエスト組み立てのテスト
final class NightReminderTests: XCTestCase {
    func testMakeRequestUsesFixedIdentifierAndCategory() {
        let request = NightReminder.makeRequest()

        XCTAssertEqual(request.identifier, "night-reminder")
        XCTAssertEqual(request.content.categoryIdentifier, "NIGHT_REMINDER")
    }

    func testMakeRequestRepeatsEveryNightAtScheduledTime() throws {
        let trigger = try XCTUnwrap(NightReminder.makeRequest().trigger as? UNCalendarNotificationTrigger)

        XCTAssertEqual(trigger.dateComponents.hour, 21)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        XCTAssertTrue(trigger.repeats)
    }
}
