#!/bin/bash
#
# appstore_screenshot_env.sh
#
# App Storeスクリーンショット生成用の環境変数と共通関数を定義するスクリプト。
# 他のスクリプトから source して使用する。
# (取り込み元: bannzai/Focus の同名スクリプト)
#

export SCHEME="AppStoreScreenshotsUITests"
# シミュレータ名は DESTINATION_SIM_NAME で上書きできる。
# 複数の worktree / セッションが同時にスクショ生成すると、同名シミュレータの
# 奪い合いで UITest が互いのアプリを落とし合うため、専用名を渡して分離する。
# iPhone 13 Pro Max (1284×2778) は App Store の 6.5インチ表示サイズの要求解像度
export DESTINATION="platform=iOS Simulator,name=${DESTINATION_SIM_NAME:-iPhone 13 Pro Max},OS=26.0"
export DERIVED_DATA_PATH=artifacts/appstore_screenshots/derived_data
export VARIANT_OUTPUT_BASE_DIR="scripts/generate_screenshots/artifacts"

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
# 1-6: ink (静かな世界観そのままの墨背景。現状の唯一のバリアント)
# 訴求軸のバリアントを追加する時は 6 枚単位で番号帯を割り当てる (7-12: 次のバリアント、...)
get_variant_name() {
  local num=$1
  case $(( (num - 1) / 6 )) in
    0) echo "ink" ;;
    *) echo "unknown" ;;
  esac
}

# スクリーンショット番号からバリアント内インデックス(0-5)を取得する関数
get_variant_index() {
  local num=$1
  echo $(( (num - 1) % 6 ))
}

# シミュレータの存在確認・自動作成 (ensure_simulator_exists) は共通関数を使う
source "$(dirname "${BASH_SOURCE[0]}")/../simulator_common.sh"
