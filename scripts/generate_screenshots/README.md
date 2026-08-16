# App Store Screenshot Scripts

AppStoreScreenshotsUITests を実行して、App Store 用スクリーンショットを多言語で自動生成するスクリプト群。
(取り込み元: bannzai/Focus の同名ディレクトリ。手法は `/appstore-screenshot-builder` skill の SnapshotUITest 方式)

## 仕組み

1. `AppStoreScreenshots/Sources/` のスクショページ (背景 + キャッチコピー + デバイスフレーム + モック画面) を SwiftUI で実装
2. `AppStoreScreenshotsUITests` が各ページを言語ごとに起動してキャプチャ (`XCTAttachment`)
3. `xcresulttool` で画像を抽出し、fastlane 形式 (`{index}_APP_IPHONE_65_{index}.png`) に整理
4. バリアント別に `artifacts/_variant-{name}/{言語}/` へ出力し、`apply_variant.sh` で `fastlane/screenshots/` に適用

## スクリプト構成

```
scripts/generate_screenshots/
├── README.md                          # このファイル
├── appstore_screenshot_env.sh         # 環境変数・共通関数 (バリアント定義・言語マッピング・シミュレータ自動作成)
├── build_appstore_screenshot.sh       # build-for-testing
├── run_appstore_screenshot.sh         # 個別テストを test-without-building で実行
├── organize_appstore_screenshots.sh   # 抽出画像を fastlane 形式に整理
├── generate_appstore_screenshots.sh   # メインスクリプト (ビルド → 実行 → 抽出 → 整理)
└── apply_variant.sh                   # 選択バリアントを fastlane/screenshots/ に適用
```

## 使い方

```bash
# 全言語 (ja, en)・全番号で生成
./scripts/generate_screenshots/generate_appstore_screenshots.sh

# 1枚だけ日本語で生成 (動作確認用)
./scripts/generate_screenshots/generate_appstore_screenshots.sh -l "ja" -n "1"

# 並列数・ビルドスキップ・上書き
./scripts/generate_screenshots/generate_appstore_screenshots.sh -p 1 --skip-build --overwrite

# 生成したバリアントを fastlane/screenshots/ に適用
./scripts/generate_screenshots/apply_variant.sh ink
```

## バリアントと番号

スクリーンショット番号とバリアントの対応は `appstore_screenshot_env.sh` の `get_variant_name` が SSOT。
現状は 1〜6 が `ink` (静かな世界観そのままの墨背景)、7〜12 が `washi` (温白地に墨の太字見出し)、
13〜18 が `dawn` (墨背景 + 夜明けグラデーション強め + 太字見出し) の 3 バリアント。
訴求軸のバリアントを追加する時は 6 枚単位で番号帯を割り当て、対応する
`AppStoreScreenshots/Sources/Layouts/` のレイアウト・ページと
`AppStoreScreenshotsUITests/Features/AppStoreScreenshot/` のテストを追加する。

## 対象言語

`AppStoreScreenshotsUITests/Languages.swift` が SSOT。現状は ja / en の 2 言語。
fastlane ディレクトリ名への変換 (en → en-US) は `appstore_screenshot_env.sh` の `map_language_to_fastlane` で行う。

## 前提条件

- Xcode (xcresulttool 同梱)
- jq (`brew install jq`)
- iOS 26.0 ランタイムのシミュレータ (無ければ `iPhone 13 Pro Max` を自動作成する)

## 注意事項

- UITest はローカルシミュレータでしか実行できないため、リモート simulator (simtunnel) では生成できない
  (CLAUDE.md「検証方法」のローカル sim フォールバックに該当)
- 複数 worktree で同時に生成する時は `DESTINATION_SIM_NAME` で専用シミュレータ名を渡して分離する
