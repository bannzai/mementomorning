#!/bin/bash
#
# appstore_screenshot_env.sh
#
# App Storeスクリーンショット生成用の環境変数と共通関数を定義するスクリプト。
# 他のスクリプトから source して使用する。
# (取り込み元: bannzai/Focus の同名スクリプト)
#

export SCHEME="AppStoreScreenshotsUITests"
export DERIVED_DATA_PATH=artifacts/appstore_screenshots/derived_data
export VARIANT_OUTPUT_BASE_DIR="scripts/generate_screenshots/artifacts"

# シミュレータの存在確認・自動作成 (ensure_simulator_exists) とランタイムバージョン解決
# (resolve_ios_runtime_version) の共通関数。DESTINATION の組み立てで使うため先頭で読み込む
source "$(dirname "${BASH_SOURCE[0]}")/../simulator_common.sh"

# 撮影に使う iOS ランタイムの実バージョン (deployment target と同じ iOS 26 系)。
# Xcode 更新で 26.0 → 26.0.1 のように進み、固定値では xcodebuild の destination に
# 一致しなくなるため実行時に解決する (選定基準は resolve_ios_runtime_version を参照)。
# 空 (ランタイム無し) はここでは許容する。本ファイルは apply_variant.sh など撮影しない
# スクリプトからも source されるため、必須チェックは撮影を行うスクリプト側で行う
SCREENSHOT_OS_VERSION="${SCREENSHOT_OS_VERSION:-$(resolve_ios_runtime_version 26)}"
export SCREENSHOT_OS_VERSION

# 撮影デバイス (App Store Connect の表示サイズ区分)。
#   69: 6.9 インチ (iPhone 17 Pro Max, 1320×2868)。ASC で必須の表示サイズ
#   65: 6.5 インチ (iPhone 13 Pro Max, 1284×2778)。任意 (未提供なら 6.9 インチの縮小が使われる)
# SCREENSHOT_DEVICES は生成・適用の対象デバイス一覧 (カンマ区切り。generate の -d で上書き)、
# SCREENSHOT_DEVICE は現在の 1 デバイス (generate がデバイスごとに export し、子スクリプトが引き継ぐ)
export SCREENSHOT_DEVICES="${SCREENSHOT_DEVICES:-69,65}"

# デバイス区分から出力ファイル名に使う表示サイズ名を返す関数。
# 名前は fastlane deliver の DisplayType (Spaceship::ConnectAPI::AppScreenshotSet::DisplayType) に合わせる。
# deliver は 6.9 インチ (1320×2868) を APP_IPHONE_67 として扱う (判定自体は画像の解像度で行われるが、名前も一致させて紛れをなくす)
# Usage: get_display_type <69|65>
get_display_type() {
  case "$1" in
    69) echo "APP_IPHONE_67" ;;
    65) echo "APP_IPHONE_65" ;;
    *) echo "Error: 未対応の SCREENSHOT_DEVICE です: $1 (対応: 69, 65)" >&2; return 1 ;;
  esac
}

# デバイス区分からシミュレータのデバイスタイプ名を返す関数
# Usage: get_device_type_name <69|65>
get_device_type_name() {
  case "$1" in
    69) echo "iPhone 17 Pro Max" ;;
    65) echo "iPhone 13 Pro Max" ;;
    *) echo "Error: 未対応の SCREENSHOT_DEVICE です: $1 (対応: 69, 65)" >&2; return 1 ;;
  esac
}

# 現在の撮影デバイスを設定し、依存する環境変数 (表示サイズ名・デバイスタイプ・DESTINATION) を更新する関数。
# シミュレータ名は DESTINATION_SIM_NAME で上書きできる。
# 複数の worktree / セッションが同時にスクショ生成すると、同名シミュレータの
# 奪い合いで UITest が互いのアプリを落とし合うため、専用名を渡して分離する
# (専用名は 1 デバイス分にしか付けられないため、渡す時は generate の -d で 1 デバイスに絞る)。
# Usage: configure_screenshot_device <69|65>
configure_screenshot_device() {
  export SCREENSHOT_DEVICE="$1"
  SCREENSHOT_DISPLAY_TYPE=$(get_display_type "$SCREENSHOT_DEVICE") || return 1
  export SCREENSHOT_DISPLAY_TYPE
  SCREENSHOT_DEVICE_TYPE=$(get_device_type_name "$SCREENSHOT_DEVICE") || return 1
  export SCREENSHOT_DEVICE_TYPE
  # simulator_common.sh の自動作成が使うデバイスタイプ (専用名のシミュレータでも正しい機種で作る)
  export DESTINATION_SIM_DEVICE_TYPE="$SCREENSHOT_DEVICE_TYPE"
  export DESTINATION="platform=iOS Simulator,name=${DESTINATION_SIM_NAME:-$SCREENSHOT_DEVICE_TYPE},OS=${SCREENSHOT_OS_VERSION}"
}

# 既定は 6.9 インチ。generate がデバイスごとに configure_screenshot_device を呼び直し、
# 子スクリプト (run / organize) は export 済みの SCREENSHOT_DEVICE を引き継ぐ
configure_screenshot_device "${SCREENSHOT_DEVICE:-69}" || return 1

# テストファイルパスからテスト実行パスとartifactパスを取得する共通関数
# Usage: get_test_info <test_file_path>
# Returns: TEST_PATH ARTIFACT_PATH (space separated)
get_test_info() {
  local test_file=$1
  local filename=$(basename "$test_file" .swift)
  local test_path="AppStoreScreenshotsUITests/${filename}/testSnapshot"
  local artifact_path="artifacts/appstore_screenshots/${filename}/testSnapshot"
  echo "$test_path $artifact_path"
}

# BCP47言語コードをfastlane用ディレクトリ名にマッピングする関数
# fastlane/metadata/ のディレクトリ構成 (ja / en-US) と揃える
map_language_to_fastlane() {
  local lang=$1
  case "$lang" in
    "en") echo "en-US" ;;
    *) echo "$lang" ;;
  esac
}

# スクリーンショット番号からバリアント名を取得する関数
# 1-6: ink (静かな世界観そのままの墨背景)
# 7-12: washi (温白地に墨の太字見出し。ストア一覧での視認性重視)
# 13-18: dawn (墨背景 + 夜明けグラデーション強め + 太字見出し)
# 19-24: kumo (明るい雲色の地 + 左揃え太字見出し + ブランドラベル。stoic. 型)
# 25-30: kohaku (夜明け色のベタ地 + 墨の太字見出し。5 Minute Journal 型)
# 31-36: bold (墨背景 + 極太・左揃え見出し。Alarmy 型)
# 37-42: hero (1 枚目のクリエイティブ案の比較バンド。fastlane へは適用しない)
# 訴求軸のバリアントを追加する時は 6 枚単位で番号帯を割り当てる (43-48: 次のバリアント、...)
get_variant_name() {
  local num=$1
  case $(( (num - 1) / 6 )) in
    0) echo "ink" ;;
    1) echo "washi" ;;
    2) echo "dawn" ;;
    3) echo "kumo" ;;
    4) echo "kohaku" ;;
    5) echo "bold" ;;
    6) echo "hero" ;;
    *) echo "unknown" ;;
  esac
}

# スクリーンショット番号からバリアント内インデックス(0-5)を取得する関数
get_variant_index() {
  local num=$1
  echo $(( (num - 1) % 6 ))
}
