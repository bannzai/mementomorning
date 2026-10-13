#!/usr/bin/env bash
#
# verify_iphone_duo_screenshots.sh
#
# iPhone Duo 用スクリーンショットが App Store Connect の仕様を満たすことを機械検証するスクリプト。
# 言語ごとに、外側 (1398×2034) と内側 (2853×2007) の枚数・px 寸法・alpha なし・ホームインジケーターの写り込み無し (外側・内側とも) を検査し、
# 1 つでも外れていれば一覧を出して exit 1 で終わる。
# 寸法の出典: Apple「Screenshot specifications」の iPhone Duo の節
# https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
# (appstore-screenshot-builder skill references/iphone-duo.md の表と同じ値)
#
# 【使い方】
# $ ./scripts/generate_screenshots/verify_iphone_duo_screenshots.sh [検査するディレクトリ]
#
# 引数:
#   $1: 検査するディレクトリ (省略時: appstore/iphone-duo-screenshots。配下に {lang}/ がある前提)
#
# 環境変数:
#   VERIFY_VARIANT_NAME: 期待枚数を数えるバリアント名 (省略時: washi)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT_DIR="$SCRIPT_DIR/../../"
cd "$PROJECT_ROOT_DIR"

source scripts/generate_screenshots/appstore_screenshot_env.sh

TARGET_DIR="${1:-$(get_apply_destination_dir duo-outer)}"
VARIANT_NAME="${VERIFY_VARIANT_NAME:-washi}"

if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: ディレクトリがありません: $TARGET_DIR" >&2
  exit 1
fi

# 期待枚数 = バリアントの番号帯に属するテストファイル数 (apply_variant.sh と同じ数え方)
expected_count=0
for test_file in AppStoreScreenshotsUITests/Features/AppStoreScreenshot/AppStoreScreenshot*PageSnapshotUITest.swift; do
  [ -f "$test_file" ] || continue
  screenshot_number=$(basename "$test_file" .swift | sed -E 's/AppStoreScreenshot([0-9]+)PageSnapshotUITest/\1/')
  if [ "$(get_variant_name "$screenshot_number")" = "$VARIANT_NAME" ]; then
    expected_count=$((expected_count + 1))
  fi
done

# 対象言語は撮影言語の SSOT (AppStoreScreenshotsUITests/Languages.swift) から取る
required_langs=$(sed -n 's/^ *("\([^"]*\)",.*/\1/p' AppStoreScreenshotsUITests/Languages.swift | while IFS= read -r code; do map_language_to_fastlane "$code"; done)

errors=""
checked=0
# 1 枚の px 寸法・alpha・(内側のみ) ホームインジケーターの写り込みを検査し、外れていれば errors に追記する
# Usage: check_image <png> <期待幅> <期待高さ> <duo-outer|duo-inner>
check_image() {
  local file=$1
  local expected_width=$2
  local expected_height=$3
  local width height alpha
  width=$(sips -g pixelWidth "$file" | awk '/pixelWidth/ {print $2}')
  height=$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')
  alpha=$(sips -g hasAlpha "$file" | awk '/hasAlpha/ {print $2}')
  checked=$((checked + 1))
  if [ "$width" != "$expected_width" ] || [ "$height" != "$expected_height" ]; then
    errors+="  - $file: 寸法 ${width}×${height} (期待 ${expected_width}×${expected_height})"$'\n'
  fi
  if [ "$alpha" != "no" ]; then
    errors+="  - $file: hasAlpha=$alpha (期待 no)"$'\n'
  fi
  # 外側・内側ともホスト側の simctl で撮るためシステムのオーバーレイが残り得る (has_home_indicator のコメント)。6.9 / 6.5 インチは XCTest の撮影で写らない
  if is_host_capture_device "$4" && has_home_indicator "$file"; then
    errors+="  - $file: ホームインジケーターが写っています"$'\n'
  fi
}

for lang in $required_langs; do
  lang_dir="$TARGET_DIR/$lang"
  if [ ! -d "$lang_dir" ]; then
    errors+="  - $lang: 言語ディレクトリがありません ($lang_dir)"$'\n'
    continue
  fi
  for device in duo-outer duo-inner; do
    display_type=$(get_display_type "$device")
    case "$device" in
      duo-outer) expected_width=1398; expected_height=2034 ;;
      duo-inner) expected_width=2853; expected_height=2007 ;;
    esac
    count=0
    for file in "$lang_dir"/*_"${display_type}"_*.png; do
      [ -f "$file" ] || continue
      count=$((count + 1))
      check_image "$file" "$expected_width" "$expected_height" "$device"
    done
    if [ "$count" -ne "$expected_count" ]; then
      errors+="  - $lang ($display_type): ${count}/${expected_count} 枚"$'\n'
    fi
  done
done

if [ -n "$errors" ]; then
  echo "NG: iPhone Duo のスクリーンショットが仕様を満たしていません ($TARGET_DIR)"
  printf '%s' "$errors"
  exit 1
fi

echo "OK: $TARGET_DIR の iPhone Duo スクリーンショット $checked 枚 (言語: $(echo "$required_langs" | tr '\n' ' ')× 外側 1398×2034 / 内側 2853×2007、各 $expected_count 枚、alpha なし)"
