# Memento Morning

毎朝「今日死ぬとしたら何をやりたいか」に答えてアラームを止める目覚ましアプリ。

## 概要
@documents/PROJECT.md

## Xcode プロジェクト構成の変更

- `MementoMorning.xcodeproj` をプロジェクト構成の唯一の正とする。XcodeGen と `project.yml` は使わず、`xcodegen generate` を実行しない（理由: [ADR 0002](documents/adr/0002-manage-xcode-project-directly.md)）
- ターゲット、ファイル、Build Settings、Build Phases、Scheme、Swift Package の変更は Xcode の GUI で行う。自動化が必要な場合は `MementoMorning.xcodeproj/project.pbxproj` を直接編集する
- 変更後は `git diff -- MementoMorning.xcodeproj/project.pbxproj` で意図した差分だけであることを確認し、下記のビルドとテストを実行する

## 検証方法

- ユニットテスト・シミュレータビルド: xcodebuild (ログは ./tmp/build.log に保存し、全文を warning / error で検査する)
- 動作確認 (UI・挙動): `/ios-simulator` skill を起点にする。本リポジトリは public のため、**simtunnel (GitHub Actions macOS Runner 上のリモート iOS Simulator) を通じて行う**。caller workflow は `.github/workflows/simulator-session.yml`
  - Maestro E2E・XCUITest・`xcrun simctl` を伴う手順はリモート実行できないため、その場合のみローカル sim-boot (`/sim-manager`) に倒す (使い分けの詳細は `/ios-simulator` skill Phase 1)
- アラーム発火の確認は「1〜2分後のアラーム」で行う。発火判定は画面表示で行う (シミュレータは sound `.default` だと鳴らない癖がある)

<!-- ai-review-config begin -->
<!--
このブロックは自動生成です。直接編集せず、テンプレートを更新してから再生成してください。
内容は AI コードレビュー時の挙動指示であり、コードベース自体への規約ではありません。
-->

## レビュー時の応答スタイル

- 応答は日本語で行う

## レビュー範囲外

以下は自動レビューで指摘しない (別の検出経路があるため):

- コンパイルエラー・型エラー (ローカル/CI のビルドで検出される)
- Lint/フォーマット違反 (リンター・フォーマッターで検出される)
<!-- ai-review-config end -->
