#!/usr/bin/env bash
#
# capture_host_screenshots.sh
#
# UITest が表示したページをホスト側から xcrun simctl で撮影する監視スクリプト。
# iPhone Duo の内側ディスプレイは XCTest の API ではストア仕様の寸法 (2853×2007) で撮れない
# (AppStoreScreenshotsUITests/XCTestCase+Snapshot.swift のコメントと
# appstore-screenshot-builder skill references/iphone-duo.md の実測) ため、
# テストと目印のファイルで同期して `simctl io screenshot --display=primary-1` で撮る。
# 外側 (閉じた姿勢。--display=primary) も同じ経路で撮り、どちらもホームインジケーターが消えるまで撮り直す
# (理由は appstore_screenshot_env.sh の is_host_capture_device と has_home_indicator のコメント)。
# ディスプレイ名は `simctl io <UDID> enumerate` の Device Name で、閉じた姿勢の実測は primary = 1398×2034 (外側)、
# primary-1 = 2007×2853 (内側の縦向き)。開いた姿勢では primary = 2034×1398、primary-1 = 2853×2007 (iOS 27.1 の iPhone Duo)。
#
# 同期の手順 (テスト側は XCTestCase+Snapshot.swift):
#   1. テストがページを表示し、<作業ディレクトリ>/<name>.ready を書く
#   2. 本スクリプトが撮影し、alpha を落として <作業ディレクトリ>/<name>.png に置き、<name>.done を書く
#   3. テストが .done を見て次のページへ進む
# 撮った画像は xcresulttool export attachments と同じ形の manifest.json にまとめ、
# organize_appstore_screenshots.sh がそのまま読めるようにする。
#
# 【使い方】
# $ ./scripts/generate_screenshots/capture_host_screenshots.sh <作業ディレクトリ> <xcodebuild の PID>
#
# 引数:
#   $1: 作業ディレクトリ (絶対パス。run_appstore_screenshot.sh が TEST_RUNNER_SNAPSHOT_HOST_CAPTURE_DIR として渡したもの)
#   $2: 監視を終える条件になる xcodebuild の PID (終了したら残りの .ready を処理して終わる)
#
# 環境変数 (appstore_screenshot_env.sh が設定。configure_screenshot_device 済みであること):
#   DESTINATION_SIM_RESOLVED_NAME / SCREENSHOT_DEVICE_OS_VERSION: 撮影対象の simulator を UDID に解決する
#   SCREENSHOT_DEVICE: duo-inner なら内側ディスプレイ (primary-1)、それ以外は外側 (primary) を撮る
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT_DIR="$SCRIPT_DIR/../../"
cd "$PROJECT_ROOT_DIR"

source scripts/generate_screenshots/appstore_screenshot_env.sh

CAPTURE_DIR=$1
XCODEBUILD_PID=$2

if ! command -v magick &> /dev/null; then
  echo "Error: magick (ImageMagick) が必要です。brew install imagemagick" >&2
  exit 1
fi

udid=$(resolve_simulator_udid "$DESTINATION_SIM_RESOLVED_NAME" "$SCREENSHOT_DEVICE_OS_VERSION")
if [ -z "$udid" ]; then
  echo "Error: simulator '$DESTINATION_SIM_RESOLVED_NAME' (iOS $SCREENSHOT_DEVICE_OS_VERSION) の UDID を解決できません" >&2
  exit 1
fi

# is_host_capture_device は外側 (duo-outer) でも真になるため、ディスプレイの選択は SCREENSHOT_DEVICE で直接分ける
# (外側を primary-1 で撮ると、閉じた姿勢でも内側の縦向き 2007×2853 が返り、仕様の 1398×2034 にならない。本 PR の生成で実測)
display="primary"
if [ "$SCREENSHOT_DEVICE" = "duo-inner" ]; then
  display="primary-1"
fi

mkdir -p "$CAPTURE_DIR"
MANIFEST_FILE="$CAPTURE_DIR/manifest.json"
# 前回の実行の manifest が残っていると organize が古い画像名を探すため、空の一覧から始める
echo '[{"attachments":[]}]' > "$MANIFEST_FILE"

echo "==== Host capture: udid=$udid display=$display dir=$CAPTURE_DIR ===="

# .ready 1 つを撮影して .done を返す
capture_one() {
  local ready_file=$1
  local name
  name=$(basename "$ready_file" .ready)
  local raw_file="$CAPTURE_DIR/$name.raw.png"
  local png_file="$CAPTURE_DIR/$name.png"

  # ホームインジケーターの自動非表示 (persistentSystemOverlays(.hidden) は最終タッチから数秒後に消える) を待ってから撮る。
  # テスト側は目印を書く前に 6 秒待つが、消えるまでの時間はページ・負荷で変わり、固定の待ち (4 秒) では
  # 24 枚中 9 枚に写った (本 PR の本番生成で実測。has_home_indicator のコメントと同じ数) ため、撮った画像を has_home_indicator で検査し、消えるまで撮り直す。
  # 上限 15 回 × 2 秒 = 30 秒は、テスト側が .done を待つ 120 秒より十分短く、観測した消えるまでの時間 (10 秒前後) の 3 倍
  local attempt=1
  while true; do
    xcrun simctl io "$udid" screenshot --display="$display" "$raw_file" > /dev/null
    # simctl の画像は alpha 付きで、App Store Connect は alpha なしを要求する (references/iphone-duo.md の 6)
    magick "$raw_file" -alpha remove -alpha off "$png_file"
    rm -f "$raw_file"
    if ! has_home_indicator "$png_file"; then
      break
    fi
    if [ "$attempt" -ge 15 ]; then
      echo "Warning: $name.png は 15 回撮り直してもホームインジケーターが写っています。verify_iphone_duo_screenshots.sh で NG になります" >&2
      break
    fi
    attempt=$((attempt + 1))
    sleep 2
  done

  local tmp_manifest="$MANIFEST_FILE.tmp"
  jq --arg file "$name.png" --arg name "$name.png" \
    '.[0].attachments += [{"exportedFileName": $file, "suggestedHumanReadableName": $name}]' \
    "$MANIFEST_FILE" > "$tmp_manifest"
  mv "$tmp_manifest" "$MANIFEST_FILE"

  rm -f "$ready_file"
  touch "$CAPTURE_DIR/$name.done"
  echo "Captured: $name.png ($(sips -g pixelWidth -g pixelHeight "$png_file" | awk '/pixel/ {printf "%s ", $2}') attempts=$attempt)"
}

process_pending() {
  local ready_file
  for ready_file in "$CAPTURE_DIR"/*.ready; do
    [ -f "$ready_file" ] || continue
    capture_one "$ready_file"
  done
}

while kill -0 "$XCODEBUILD_PID" 2>/dev/null; do
  process_pending
  sleep 0.5
done
# xcodebuild が終わった直後に書かれた .ready を取りこぼさないよう最後にもう一度処理する
process_pending

echo "==== Host capture finished: $(jq '.[0].attachments | length' "$MANIFEST_FILE") file(s) ===="
