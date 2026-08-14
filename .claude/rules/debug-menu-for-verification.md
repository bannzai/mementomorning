# 検証用の状態作り込みは DEBUG 開発者メニューで行う

動作確認・E2E テストで到達困難な状態 (サンプルデータ投入・課金状態・日時経過等) を作る時は、起動引数・環境変数ではなく、アプリ内の DEBUG 限定開発者メニュー (`DebugMenuPage`) に操作を追加する。

## 理由

- 本リポジトリは public で、動作確認は simtunnel (リモート iOS Simulator) を優先する (CLAUDE.md「検証方法」)。起動引数はリモート simulator に渡せない (`xcrun simctl launch` をローカルから実行できない) が、開発者メニューは mobile-mcp 互換ツールのタップで操作できるため simtunnel のまま検証できる
- Maestro / mobile-mcp / 手動のどの経路でも同じ手順で状態を作れ、E2E テストにそのまま流用できる

## ルール

- 開発者メニューは `#if DEBUG` でリリースビルドから完全除外する
- 操作要素には `accessibilityIdentifier` (`debug_` prefix) を付与する (Maestro / mobile-mcp からの検出用)
- デバッグ操作は冪等にする (再実行してもデータが壊れない)
- 実装パターンの詳細は debug-function skill (パターンカタログ・SwiftUI ガイド) を参照する

## 経緯

issue #5 / #7 の動作確認で、起動引数によるシーダー設計が simtunnel を使えない原因になった (再発防止の全体像: https://github.com/bannzai/castle/issues/487 )
