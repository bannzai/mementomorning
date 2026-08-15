import Foundation

/// ユニットテスト実行中かどうか
var isUnitTest: Bool { NSClassFromString("XCTestCase") != nil }

/// UITest 実行中かどうか
var isUITest: Bool { ProcessInfo.processInfo.arguments.contains("isUITest") }

/// 多言語スクリーンショット撮影 (MementoMorningSnapshotUITests) の実行中かどうか
var isSnapshotUITest: Bool { ProcessInfo.processInfo.arguments.contains("isSnapshotUITest") }

/// Xcode Preview 実行中かどうか
var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }
