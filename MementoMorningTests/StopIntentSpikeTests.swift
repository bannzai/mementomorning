import XCTest
@testable import MementoMorning

/// appendStopIntentSpikeLog のテスト。
/// TEST_HOST で実アプリの UserDefaults.standard を共有するため、前後でスパイクログのキーを掃除する
final class StopIntentSpikeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: .stopIntentSpikeLog)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: .stopIntentSpikeLog)
        super.tearDown()
    }

    func testAppendCreatesLogWhenEmpty() {
        appendStopIntentSpikeLog(message: "first")

        let stopIntentSpikeLog = UserDefaults.standard.string(forKey: .stopIntentSpikeLog)
        XCTAssertEqual(stopIntentSpikeLog?.hasSuffix("first"), true)
        XCTAssertEqual(stopIntentSpikeLog?.components(separatedBy: "\n").count, 1)
    }

    func testAppendKeepsOrderAcrossCalls() {
        appendStopIntentSpikeLog(message: "first")
        appendStopIntentSpikeLog(message: "second")

        let lines = UserDefaults.standard.string(forKey: .stopIntentSpikeLog)?.components(separatedBy: "\n")
        XCTAssertEqual(lines?.count, 2)
        XCTAssertEqual(lines?[0].hasSuffix("first"), true)
        XCTAssertEqual(lines?[1].hasSuffix("second"), true)
    }
}
