# App Store Screenshot Scripts

AppStoreScreenshotsUITests を実行して、App Store 用スクリーンショットを多言語で自動生成するスクリプト群。
(取り込み元: bannzai/Focus の同名ディレクトリ。手法は `/appstore-screenshot-builder` skill の SnapshotUITest 方式)

## 仕組み

1. `AppStoreScreenshots/Sources/` のスクショページ (背景 + キャッチコピー + デバイスフレーム + モック画面) を SwiftUI で実装
2. `AppStoreScreenshotsUITests` が各ページを言語ごとに起動してキャプチャ (`XCTAttachment`)
3. `xcresulttool` で画像を抽出し、fastlane 形式 (`{index}_{表示サイズ名}_{index}.png`) に整理
4. バリアント別に `artifacts/_variant-{name}/{言語}/` へ出力し、`apply_variant.sh` で `fastlane/screenshots/` に適用

## スクリプト構成

```
scripts/generate_screenshots/
├── README.md                          # このファイル
├── appstore_screenshot_env.sh         # 環境変数・共通関数 (バリアント定義・撮影デバイス定義・言語マッピング・シミュレータ自動作成)
├── build_appstore_screenshot.sh       # build-for-testing
├── run_appstore_screenshot.sh         # 個別テストを test-without-building で実行
├── organize_appstore_screenshots.sh   # 抽出画像を fastlane 形式に整理
├── capture_host_screenshots.sh        # iPhone Duo の外側・内側ディスプレイをホスト側の simctl で撮る監視 (run_appstore_screenshot.sh が起動)
├── generate_appstore_screenshots.sh   # メインスクリプト (ビルド → 実行 → 抽出 → 整理)
├── apply_variant.sh                   # 選択バリアントを fastlane/screenshots/ (iPhone Duo は appstore/iphone-duo-screenshots/) に適用
└── verify_iphone_duo_screenshots.sh   # iPhone Duo の画像の寸法・alpha・枚数の機械検証
```

## 使い方

```bash
# 全言語 (ja, en)・全番号・全デバイス (6.9 インチ + 6.5 インチ) で生成
./scripts/generate_screenshots/generate_appstore_screenshots.sh

# 1枚だけ日本語・6.9 インチで生成 (動作確認用)
./scripts/generate_screenshots/generate_appstore_screenshots.sh -l "ja" -n "1" -d "69"

# 並列数・ビルドスキップ・上書き
./scripts/generate_screenshots/generate_appstore_screenshots.sh -p 1 --skip-build --overwrite

# 生成したバリアントを fastlane/screenshots/ に適用
./scripts/generate_screenshots/apply_variant.sh ink

# iPhone Duo (外側 + 内側) を washi で生成し、appstore/iphone-duo-screenshots/ に適用して機械検証する
./scripts/generate_screenshots/generate_appstore_screenshots.sh -d "duo-outer,duo-inner" -n "7-12" --overwrite
SCREENSHOT_DEVICES=duo-outer,duo-inner ./scripts/generate_screenshots/apply_variant.sh washi
./scripts/generate_screenshots/verify_iphone_duo_screenshots.sh
```

## バリアントと番号

スクリーンショット番号とバリアントの対応は `appstore_screenshot_env.sh` の `get_variant_name` が SSOT。
現状は 1〜6 が `ink` (静かな世界観そのままの墨背景)、7〜12 が `washi` (温白地に墨の太字見出し)、
13〜18 が `dawn` (墨背景 + 夜明けグラデーション強め + 太字見出し)、19〜24 が `kumo`
(明るい雲色の地 + 左揃え太字見出し + ブランドラベル)、25〜30 が `kohaku` (夜明け色のベタ地 + 墨の太字見出し)、
31〜36 が `bold` (墨背景 + 極太・左揃え見出し) の 6 バリアント。
37〜42 の `hero` は 1 枚目のクリエイティブ案の比較バンドで、fastlane へは適用しない。
訴求軸のバリアントを追加する時は 6 枚単位で番号帯を割り当て、対応する
`AppStoreScreenshots/Sources/Layouts/` のレイアウト・ページと
`AppStoreScreenshotsUITests/Features/AppStoreScreenshot/` のテストを追加する。

## 撮影デバイス (表示サイズ)

デバイスと出力ファイル名の対応は `appstore_screenshot_env.sh` の `get_display_type` / `get_device_type_name` が SSOT。
`-d` (または `SCREENSHOT_DEVICES`) で指定し、既定は両方 (`69,65`)。

| 区分 | シミュレータ | 解像度 | ファイル名 | App Store Connect での扱い |
| --- | --- | --- | --- | --- |
| `69` | iPhone 17 Pro Max | 1320×2868 | `{index}_APP_IPHONE_67_{index}.png` | 6.9 インチ (必須) |
| `65` | iPhone 13 Pro Max | 1284×2778 | `{index}_APP_IPHONE_65_{index}.png` | 6.5 インチ (任意。未提供なら 6.9 インチの縮小が使われる) |
| `duo-outer` | iPhone Duo (閉じた姿勢) | 1398×2034 | `{index}_APP_IPHONE_DUO_OUTER_{index}.png` | iPhone Duo の外側ディスプレイ (2027 年 4 月から iOS 27.1 SDK 以降のアプリで必須) |
| `duo-inner` | iPhone Duo (開いた姿勢) | 2853×2007 (横) | `{index}_APP_IPHONE_DUO_INNER_{index}.png` | iPhone Duo の内側ディスプレイ (同上) |

ファイル名の表示サイズ名は fastlane deliver の DisplayType に合わせる (deliver は 6.9 インチを `APP_IPHONE_67` として扱う。
アップロード時の区分判定は画像の解像度で行われる)。
参照: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/

### iPhone Duo

作り方の SSOT は appstore-screenshot-builder skill の `references/iphone-duo.md`。本リポジトリでの決めごと:

- 内側は横 (2853×2007) で作る。開いた姿勢の simulator は横向きになり、`xcrun simctl io <UDID> screenshot --display=primary-1` が回転なしでこの寸法を返すため (同 references の実測)。横長の画面用に `AppStoreScreenshotWashiLayout` が幅 regular の時だけ、見出しを左・縦向きのデバイスフレームを右に置く構成に切り替わる
- 外側・内側ともホスト側で撮る。テストが目印のファイルを書いて待機し、`capture_host_screenshots.sh` がホスト側の simctl で撮って alpha を落とす (同期の手順は `AppStoreScreenshotsUITests/XCTestCase+Snapshot.swift`)。外側は閉じた姿勢で `--display=primary` が 1398×2034 を返す (`primary-1` は閉じた姿勢でも内側の縦向き 2007×2853 を返す。iOS 27.1 の iPhone Duo で `xcrun simctl io <UDID> screenshot` を両方に対して実行して確認)。内側は XCTest の API ではストア仕様の寸法で撮れないため。外側は XCTest でも撮れるが、iPhone Duo の比率では端末フレームの下端が画面内に入り、ホームインジケーターがまだ消えていない時にフレームに重なって写るため、撮った画像を `has_home_indicator` (`appstore_screenshot_env.sh`) で検査して消えるまで撮り直す。`verify_iphone_duo_screenshots.sh` も同じ判定で写り込みを NG にする
- 姿勢の切り替えは ios-simulator skill の `duo-pose.sh` (Device Hub のウィンドウを操作するためローカルの Mac 限定)。iOS 27.1 以上のランタイムと ImageMagick (`brew install imagemagick`) が必要
- `apply_variant.sh` は Duo の画像を `fastlane/screenshots/` ではなく `appstore/iphone-duo-screenshots/{locale}/` に置く。fastlane deliver 2.241.0 は Duo の寸法を知らず、置くとアップロード全体が検証で止まる (同 references の「アップロード経路」の表)
- App Store Connect へは手で上げる。Web UI の対象アプリ → バージョン → iPhone Duo の枠に、`appstore/iphone-duo-screenshots/{locale}/` の外側 6 枚と内側 6 枚を `{index}` の順で入れる。同 references によると外側と内側は同じ枠 (最大 10 枚) に入るため、10 枚を超える分はどちらかを減らす (未確認: Web UI が外側と内側を分けて受けるか)。`asc` 5.12.0 以降なら `asc screenshots upload --device-type APP_IPHONE_DUO` で上げられるが、内側の寸法をサーバが受け付けるかは誰も確かめていない (同 references)

## 対象言語

`AppStoreScreenshotsUITests/Languages.swift` が SSOT。現状は ja / en の 2 言語。
fastlane ディレクトリ名への変換 (en → en-US) は `appstore_screenshot_env.sh` の `map_language_to_fastlane` で行う。

## 前提条件

- Xcode (xcresulttool 同梱)
- jq (`brew install jq`)
- iOS 26.0 ランタイムのシミュレータ (無ければ `iPhone 17 Pro Max` / `iPhone 13 Pro Max` を自動作成する)

## 注意事項

- UITest はローカルシミュレータでしか実行できないため、リモート simulator (simtunnel) では生成できない
  (CLAUDE.md「検証方法」のローカル sim フォールバックに該当)
- 複数 worktree で同時に生成する時は `DESTINATION_SIM_NAME` で専用シミュレータ名を渡して分離する (専用名は 1 機種分にしか付けられないため、`-d` で 1 機種に絞って実行する。`duo-outer,duo-inner` は同じ機種なので一緒に指定できる)
- 生成した画像は `apply_variant.sh` で `fastlane/screenshots/{locale}/` に配置し、git にコミットする (Focus は別リポジトリ管理だが、本プロジェクトは同一リポジトリで管理する)
