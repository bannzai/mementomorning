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

SCRIPT_DIR="$(cd `dirname $0` && pwd -P)"
PROJECT_ROOT_DIR=$SCRIPT_DIR/../../
cd $PROJECT_ROOT_DIR

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

# 各言語ディレクトリを処理
applied=0
for lang_dir in "$VARIANT_DIR"/*/; do
  if [ ! -d "$lang_dir" ]; then
    continue
  fi

  lang=$(basename "$lang_dir")
  dest_dir="$FASTLANE_DIR/$lang"
  mkdir -p "$dest_dir"

  # バリアントのスクリーンショットを適用先にコピー（上書き）
  cp -f "$lang_dir"*.png "$dest_dir/" 2>/dev/null || true
  file_count=$(ls -1 "$lang_dir"*.png 2>/dev/null | wc -l | tr -d ' ')
  echo "Applied: $lang ($file_count files)"
  applied=$((applied + file_count))
done

echo "==== Apply complete: $applied files applied ===="
echo "==== Screenshots ready in: $FASTLANE_DIR ===="
