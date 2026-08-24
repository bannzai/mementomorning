# 検証用の状態作り込みは開発者メニューで行う

動作確認・E2E テストで到達困難な状態 (サンプルデータ投入・課金状態・日時経過等) を作る時は、起動引数・環境変数ではなく、アプリ内の開発者メニュー (`DebugMenuPage`) に操作を追加する。

## 理由

- 本リポジトリは public で、動作確認は simtunnel (リモート iOS Simulator) を優先する (CLAUDE.md「検証方法」)。起動引数はリモート simulator に渡せない (`xcrun simctl launch` をローカルから実行できない) が、開発者メニューは mobile-mcp 互換ツールのタップで操作できるため simtunnel のまま検証できる
- Maestro / mobile-mcp / 手動のどの経路でも同じ手順で状態を作れ、E2E テストにそのまま流用できる

## ルール

- 開発者メニューの導線と検証用フラグの効果は `isDeveloperMenuUnlocked` (DEBUG は常時 true、リリースビルドは TestFlight 配布判定時のみ true。実体は `DeveloperMenuGate.swift`) でゲートし、App Store 配布では解放しない (issue #128。TestFlight は App Store と同一の Release バイナリのため `#if DEBUG` では提供できない。判定方式の意思決定は [ADR 0004](../../documents/adr/0004-testflight-developer-menu-runtime-gate.md) 参照)
- 操作要素には `accessibilityIdentifier` (`debug_` prefix) を付与する (Maestro / mobile-mcp からの検出用)
- デバッグ操作は冪等にする (再実行してもデータが壊れない)
- 実装パターンの詳細は debug-function skill (パターンカタログ・SwiftUI ガイド) を参照する

## 経緯

issue #5 / #7 の動作確認で、起動引数によるシーダー設計が simtunnel を使えない原因になった (再発防止の全体像: https://github.com/bannzai/castle/issues/487 )
