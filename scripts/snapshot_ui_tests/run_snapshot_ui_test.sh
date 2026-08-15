#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd `dirname $0` && pwd -P)"
PROJECT_ROOT_DIR=$SCRIPT_DIR/../../
cd $PROJECT_ROOT_DIR

source scripts/snapshot_ui_tests/snapshot_ui_test_env.sh

TEST=$1
RESULT_BUNDLE_PATH=$2
LANGUAGES=${3:-""}  # 第3引数: 言語指定（省略可）カンマ区切り（例: "ja,en"）

echo "==== Running test: $TEST ===="
echo "==== Result bundle: $RESULT_BUNDLE_PATH ===="
if [ -n "$LANGUAGES" ]; then
  echo "==== Languages: $LANGUAGES ===="
fi

# Prevent: xcodebuild: error: Existing file at -resultBundlePath
rm -rf "$RESULT_BUNDLE_PATH"

# 言語が指定されている場合は設定ファイルに書き込む
# UI testプロセスは環境変数を受け取れないため、ファイルベースで設定を渡す
if [ -n "$LANGUAGES" ]; then
  # macOSのtemporaryディレクトリを使用（FileManager.default.temporaryDirectoryと同じ場所）
  TMPDIR="${TMPDIR:-/tmp}"
  CONFIG_FILE="${TMPDIR}snapshot_languages.txt"
  echo "$LANGUAGES" > "$CONFIG_FILE"
  echo "==== Writing language config to: $CONFIG_FILE ===="
  export SNAPSHOT_LANGUAGES="$LANGUAGES"
fi

xcodebuild test-without-building \
  -project MementoMorning.xcodeproj \
  -scheme "$SCHEME" \
  -sdk iphonesimulator \
  -destination "$DESTINATION"  \
  -only-testing:"$TEST" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH"

# テスト完了後に設定ファイルを削除
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
  rm -f "$CONFIG_FILE"
  echo "==== Cleaned up language config file ===="
fi

echo "==== Test completed: $TEST ===="
