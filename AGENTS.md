# Memento Morning

毎朝「今日死ぬとしたら何をやりたいか」に答えてアラームを止める目覚ましアプリ。

## 概要
@documents/PROJECT.md

## 検証方法

- ユニットテスト・シミュレータビルド: xcodebuild (ログは ./tmp/build.log に保存し、全文を warning / error で検査する)
- 動作確認 (UI・挙動): `/ios-simulator` skill を起点にする。本リポジトリは public のため、**simtunnel (GitHub Actions macOS Runner 上のリモート iOS Simulator) を通じて行う**。caller workflow は `.github/workflows/simulator-session.yml`
  - Maestro E2E・XCUITest・`xcrun simctl` を伴う手順はリモート実行できないため、その場合のみローカル sim-boot (`/sim-manager`) に倒す (使い分けの詳細は `/ios-simulator` skill Phase 1)
- アラーム発火の確認は「1〜2分後のアラーム」で行う。発火判定は画面表示で行う (シミュレータは sound `.default` だと鳴らない癖がある)
- 課金 (商品の価格・購入・復元) の確認は StoreKit Configuration file (`MementoMorning.storekit`) で行う。scheme の run action に指定した StoreKit Configuration は Xcode の Run と `xcodebuild test` しか反映せず、`xcrun simctl launch` には渡す手段が無いため、install + launch でアプリを起動する simtunnel では課金フローを確認できない
  - CLI から確認する: `xcodebuild -project MementoMorning.xcodeproj -scheme MementoMorning -only-testing:MementoMorningTests/StoreKitConfigurationTests -destination 'platform=iOS Simulator,id=<UDID>' test` (SKTestSession が `MementoMorning.storekit` を読み、3 商品の価格・年額のみの 7 日間無料トライアル・購入による entitlement 付与まで検査する)。destination の runtime は iOS 26.2 以下にする (iOS 26.5 の simulator は StoreKit Testing が機能せず、テストが skip される)
  - ペイウォールの画面 (価格表示・購入・復元) を目で確認する: Xcode で MementoMorning スキームを Run する。ペイウォールは RevenueCat の offering から料金を出すため、`Config.local.xcconfig` に API key を置いた状態で起動する (key が無いと未 configure のまま見本価格の表示に倒れる)

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
