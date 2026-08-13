import Foundation

/// ユニットテスト実行中かどうか
var isUnitTest: Bool { NSClassFromString("XCTestCase") != nil }

/// UITest 実行中かどうか
var isUITest: Bool { ProcessInfo.processInfo.arguments.contains("isUITest") }

/// Xcode Preview 実行中かどうか
var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }
