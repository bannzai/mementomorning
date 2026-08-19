#!/usr/bin/env bash
#
# apply_variant.sh
#
# 選択したバリアントのスクリーンショットを fastlane/screenshots/ に適用するスクリプト。
# _variant-{name}/{lang}/* の内容を fastlane/screenshots/{lang}/* にコピー（上書き）する。
# App Store Connect にアップロードする前の準備用。
# (取り込み元: bannzai/Focus の同名スクリプト)
#
# 【使い方】
# $ ./scripts/generate_screenshots/apply_variant.sh <VARIANT_NAME>
#
# 引数:
#   $1: VARIANT_NAME - 適用するバリアント名
#       有効な値: ink (バリアントの一覧は appstore_screenshot_env.sh の get_variant_name が正)
#
# 例:
#   $ ./scripts/generate_screenshots/apply_variant.sh ink
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT_DIR="$SCRIPT_DIR/../../"
cd "$PROJECT_ROOT_DIR"

source scripts/generate_screenshots/appstore_screenshot_env.sh

VARIANT_NAME="${1:-}"
FASTLANE_DIR="fastlane/screenshots"
VARIANT_DIR="$VARIANT_OUTPUT_BASE_DIR/_variant-${VARIANT_NAME}"

# 引数チェック
if [ -z "$VARIANT_NAME" ]; then
  echo "Error: バリアント名を指定してください"
  echo ""
  echo "Usage: $0 <VARIANT_NAME>"
  echo ""
  echo "利用可能なバリアント:"
  ls -d "$VARIANT_OUTPUT_BASE_DIR"/_variant-* 2>/dev/null | sed 's|.*/_variant-||' || echo "  (なし)"
  exit 1
fi

# バリアントディレクトリの存在確認
if [ ! -d "$VARIANT_DIR" ]; then
  echo "Error: バリアントディレクトリが見つかりません: $VARIANT_DIR"
  echo ""
  echo "利用可能なバリアント:"
  ls -d "$VARIANT_OUTPUT_BASE_DIR"/_variant-* 2>/dev/null | sed 's|.*/_variant-||' || echo "  (なし)"
  exit 1
fi

echo "==== Applying variant: $VARIANT_NAME ===="
echo "==== Source: $VARIANT_DIR ===="
echo "==== Destination: $FASTLANE_DIR ===="

# バリアントの期待枚数 = このバリアントの番号帯に属するテストファイル数 × 撮影デバイス数 (SCREENSHOT_DEVICES)。
# 一部だけ生成した状態 (-n "1" や -d "69" 等) で適用すると、適用先の完成済み一式を消して欠落した素材を作るため、
# 各言語がデバイスごとに期待枚数に達していることを削除前に検証する
expected_count=0
for test_file in AppStoreScreenshotsUITests/Features/AppStoreScreenshot/AppStoreScreenshot*PageSnapshotUITest.swift; do
  [ -f "$test_file" ] || continue
  screenshot_number=$(basename "$test_file" .swift | sed -E 's/AppStoreScreenshot([0-9]+)PageSnapshotUITest/\1/')
  if [ "$(get_variant_name "$screenshot_number")" = "$VARIANT_NAME" ]; then
    expected_count=$((expected_count + 1))
  fi
done

if [ "$expected_count" -eq 0 ]; then
  echo "Error: バリアント '$VARIANT_NAME' に対応するテストが見つかりません"
  exit 1
fi

IFS=',' read -ra device_list <<< "$SCREENSHOT_DEVICES"
incomplete=""
for lang_dir in "$VARIANT_DIR"/*/; do
  [ -d "$lang_dir" ] || continue
  lang=$(basename "$lang_dir")
  for device in "${device_list[@]}"; do
    device=$(echo "$device" | tr -d ' ')
    [ -n "$device" ] || continue
    display_type=$(get_display_type "$device")
    actual_count=$(ls -1 "$lang_dir"*_"${display_type}"_*.png 2>/dev/null | wc -l | tr -d ' ')
    if [ "$actual_count" -ne "$expected_count" ]; then
      incomplete+="  - ${lang} (${display_type}): ${actual_count}/${expected_count} 枚"$'\n'
    fi
  done
done

if [ -z "$(find "$VARIANT_DIR" -name '*.png' -print -quit 2>/dev/null)" ] || [ -n "$incomplete" ]; then
  echo "Error: バリアントのスクリーンショットが揃っていません: $VARIANT_DIR"
  if [ -n "$incomplete" ]; then
    echo "$incomplete"
  fi
  echo "先に ./scripts/generate_screenshots/generate_appstore_screenshots.sh で全番号・全デバイス (SCREENSHOT_DEVICES=$SCREENSHOT_DEVICES) を生成してください"
  exit 1
fi

# 各言語ディレクトリを処理
applied=0
for lang_dir in "$VARIANT_DIR"/*/; do
  if [ ! -d "$lang_dir" ]; then
    continue
  fi

  lang=$(basename "$lang_dir")
  dest_dir="$FASTLANE_DIR/$lang"
  mkdir -p "$dest_dir"

  # 適用先に残った過去の PNG と混ざった一式を作らないよう、適用言語の既存 PNG を先に削除する
  find "$dest_dir" -maxdepth 1 -name '*.png' -delete 2>/dev/null || true

  # バリアントのスクリーンショットを適用先にコピー
  cp -f "$lang_dir"*.png "$dest_dir/" 2>/dev/null || true
  file_count=$(ls -1 "$dest_dir"/*.png 2>/dev/null | wc -l | tr -d ' ')
  echo "Applied: $lang ($file_count files)"
  applied=$((applied + file_count))
done

echo "==== Apply complete: $applied files applied ===="
echo "==== Screenshots ready in: $FASTLANE_DIR ===="
