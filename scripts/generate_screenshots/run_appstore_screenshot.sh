#!/usr/bin/env bash
#
# run_appstore_screenshot.sh
#
# 個別のApp Storeスクリーンショットテストを実行するスクリプト。
# xcodebuild test-without-building で事前ビルド済みのテストを実行する。
# (取り込み元: bannzai/Focus の同名スクリプト)
#
# 【使い方】
# $ ./scripts/generate_screenshots/run_appstore_screenshot.sh <TEST_PATH> <RESULT_BUNDLE_PATH> [LANGUAGES] [HOST_CAPTURE_DIR]
#
# 引数:
#   $1: TEST_PATH - テスト実行パス（例: AppStoreScreenshotsUITests/AppStoreScreenshot1PageSnapshotUITest/testSnapshot）
#   $2: RESULT_BUNDLE_PATH - 結果バンドル保存先（例: artifacts/appstore_screenshots/AppStoreScreenshot1PageSnapshotUITest/testSnapshot）
#   $3: LANGUAGES - 実行する言語（省略可、カンマ区切り例: "ja,en"）
#   $4: HOST_CAPTURE_DIR - ホスト側で撮影する時の作業ディレクトリ (省略可。絶対パス)。
#       指定すると XCTAttachment の代わりに、テストが表示した画面を capture_host_screenshots.sh が
#       simctl で撮り、このディレクトリに画像と manifest.json (organize が読む形式) を書く。
#       iPhone Duo の外側・内側ディスプレイ (SCREENSHOT_DEVICE=duo-outer / duo-inner) で使う
#
# 注意:
#   言語フィルタリングは TEST_RUNNER_SNAPSHOT_LANGUAGES 環境変数で行う。
#   xcodebuild の TEST_RUNNER_ プレフィックス機構により、テストランナー
#   プロセスに SNAPSHOT_LANGUAGES として引き渡される。ホスト撮影の作業ディレクトリも同じ機構で
#   SNAPSHOT_HOST_CAPTURE_DIR として渡す。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT_DIR="$SCRIPT_DIR/../../"
cd "$PROJECT_ROOT_DIR"

source scripts/generate_screenshots/appstore_screenshot_env.sh

TEST=$1
RESULT_BUNDLE_PATH=$2
LANGUAGES=${3:-""}
HOST_CAPTURE_DIR=${4:-""}

echo "==== Running test: $TEST ===="
echo "==== Result bundle: $RESULT_BUNDLE_PATH ===="
if [ -n "$LANGUAGES" ]; then
  echo "==== Languages: $LANGUAGES ===="
fi

# 言語フィルタリング用環境変数を設定
# TEST_RUNNER_ プレフィックスにより、xcodebuildがテストランナープロセスに
# SNAPSHOT_LANGUAGES として環境変数を引き渡す
if [ -n "$LANGUAGES" ]; then
  export TEST_RUNNER_SNAPSHOT_LANGUAGES="$LANGUAGES"
fi

# ホスト撮影の作業ディレクトリ。テストランナーが目印ファイル (.ready) を書き、ホストの監視が撮影して .done を返す
if [ -n "$HOST_CAPTURE_DIR" ]; then
  mkdir -p "$HOST_CAPTURE_DIR"
  export TEST_RUNNER_SNAPSHOT_HOST_CAPTURE_DIR="$HOST_CAPTURE_DIR"
  echo "==== Host capture dir: $HOST_CAPTURE_DIR ===="
fi

# 既存の結果バンドルを削除（xcodebuildエラー回避）
rm -rf "$RESULT_BUNDLE_PATH"

# テスト実行。
# -parallel-testing-enabled NO: 付けないと xcodebuild が simulator の clone (Clone 1 of <名前>) でテストを実行する。
# clone は閉じた姿勢で起動するため、iPhone Duo を開いた姿勢にしても内側ディスプレイが撮れない
# (appstore-screenshot-builder skill references/iphone-duo.md の実測)。scheme の parallelizable=NO とは別の設定
xcodebuild test-without-building \
  -project MementoMorning.xcodeproj \
  -scheme "$SCHEME" \
  -sdk iphonesimulator \
  -destination "$DESTINATION" \
  -parallel-testing-enabled NO \
  -only-testing:"$TEST" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" &
xcodebuild_pid=$!

# ホスト撮影では、テストの進行に合わせて撮る監視をテスト終了まで前面で回す。
# 監視が途中で失敗 (simctl screenshot・magick のエラー) した時は、撮影完了を待ち続ける UITest ごと xcodebuild を止めて回収する
# (残すと呼び出し元が次のテスト・リトライへ進み、同じ simulator 上で古いランナーと競合する)
if [ -n "$HOST_CAPTURE_DIR" ]; then
  if ! ./scripts/generate_screenshots/capture_host_screenshots.sh "$HOST_CAPTURE_DIR" "$xcodebuild_pid"; then
    echo "Error: ホスト撮影の監視が失敗しました。xcodebuild ($xcodebuild_pid) を停止します" >&2
    pkill -TERM -P "$xcodebuild_pid" 2>/dev/null || true
    kill -TERM "$xcodebuild_pid" 2>/dev/null || true
    wait "$xcodebuild_pid" || true
    exit 1
  fi
fi

wait "$xcodebuild_pid"

echo "==== Test completed: $TEST ===="
