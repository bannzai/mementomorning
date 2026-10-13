#!/usr/bin/env bash
#
# generate_appstore_screenshots.sh
#
# App Storeスクリーンショットを自動生成するメインスクリプト。
# AppStoreScreenshot 用の UITest をデバイス (6.9 インチ / 6.5 インチ) ごとに実行し、全言語のスクリーンショットを
# scripts/generate_screenshots/artifacts/_variant-{name}/ に生成する。
# (取り込み元: bannzai/Focus の同名スクリプト)
#
# 【目的】
# SwiftUI で構成した App Store スクリーンショット View を UITest で撮影し、
# バリアント別 artifacts に全言語分を配置する (fastlane への適用は apply_variant.sh)
#
# 【使い方】
# 1. 全スクリーンショットを全言語で生成:
#    $ ./scripts/generate_screenshots/generate_appstore_screenshots.sh
#
# 2. 特定の言語のみで生成:
#    $ ./scripts/generate_screenshots/generate_appstore_screenshots.sh -l "ja,en"
#
# 3. 特定の番号のスクリーンショットのみ生成:
#    $ ./scripts/generate_screenshots/generate_appstore_screenshots.sh -n "1-6"
#    $ ./scripts/generate_screenshots/generate_appstore_screenshots.sh -n "1,3,5"
#
# 3-2. 特定のデバイス (表示サイズ) のみで生成 (デフォルトは 6.9 インチと 6.5 インチの両方):
#    $ ./scripts/generate_screenshots/generate_appstore_screenshots.sh -d "69"
#
# 3-3. iPhone Duo の外側・内側ディスプレイを生成 (iOS 27.1 以上のランタイムと、Device Hub を操作できるローカルの Mac が必要。
#      外側・内側ともホスト側の simctl で撮る。姿勢の切り替えは ios-simulator skill の duo-pose.sh):
#    $ ./scripts/generate_screenshots/generate_appstore_screenshots.sh -d "duo-outer,duo-inner"
#
# 4. 並列数を指定して実行:
#    $ ./scripts/generate_screenshots/generate_appstore_screenshots.sh -p 2
#
# 5. ビルドをスキップして実行:
#    $ ./scripts/generate_screenshots/generate_appstore_screenshots.sh --skip-build
#
# 6. 既存スクリーンショットを上書きして再生成:
#    $ ./scripts/generate_screenshots/generate_appstore_screenshots.sh --overwrite
#
# 7. ヘルプを表示:
#    $ ./scripts/generate_screenshots/generate_appstore_screenshots.sh --help
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT_DIR="$SCRIPT_DIR/../../"
cd "$PROJECT_ROOT_DIR"

source scripts/generate_screenshots/appstore_screenshot_env.sh

# 一時ファイル・ディレクトリのクリーンアップ共通関数
cleanup_temp_files() {
  rm -rf "$TEMP_SCREENSHOTS_DIR"
}

# PIDとその全子孫プロセスを再帰的にkillする関数
# kill $(jobs -p) では直接の子プロセスしか停止できず、
# 孫プロセス（xcodebuild等）が孤児として残り続けるため再帰的に停止する
kill_descendants() {
  local pid=$1
  local children
  children=$(pgrep -P "$pid" 2>/dev/null || true)
  for child in $children; do
    kill_descendants "$child"
  done
  kill "$pid" 2>/dev/null || true
}

# 起動した iPhone Duo を閉じた姿勢に戻してから停止する (Device Hub は Booted の simulator にしか姿勢を効かせられないため、停止の前に戻す)。
# 正常終了・リトライ後の失敗・Ctrl+C のどの経路でも呼び、開いた姿勢の simulator を残さない。
# 対象は prepare_duo_simulator が控えた UDID で、UDID の解決前 (未定義・空) なら何もしない
cleanup_duo_simulator() {
  if [ "${uses_duo:-false}" = true ] && [ -n "${duo_udid:-}" ]; then
    sep "Shutting down iPhone Duo simulator: $duo_udid"
    bash "$DUO_POSE_SCRIPT" set --udid "$duo_udid" closed || true
    xcrun simctl shutdown "$duo_udid" 2>/dev/null || true
  fi
}

# Ctrl+C (SIGINT) / SIGTERM でのクリーンアップ処理
# プロセスグループ全体を停止して子プロセス（xcodebuild等）も確実に終了させる
cleanup() {
  trap - SIGINT SIGTERM
  echo "" >&3
  echo "==== Interrupted by user (Ctrl+C) ===" >&3
  echo ""
  echo "==== Interrupted by user (Ctrl+C) ===="
  local pids
  pids=$(jobs -p 2>/dev/null) || true
  for pid in $pids; do
    kill_descendants "$pid"
  done
  wait 2>/dev/null || true
  cleanup_duo_simulator
  cleanup_temp_files
  echo "==== Partial screenshots may be in $VARIANT_OUTPUT_BASE_DIR ===" >&3
  echo "==== Partial screenshots may be in $VARIANT_OUTPUT_BASE_DIR ===="
  exit 130
}
trap cleanup SIGINT SIGTERM

# オプション解析
SKIP_BUILD=false
OVERWRITE=false
LANGUAGES=""
SCREENSHOT_NUMBERS=""
DEVICES="$SCREENSHOT_DEVICES"
# 並列数のデフォルトは 1 (直列)。同一シミュレータへの並列 test 実行はランナー同士が
# kill し合い "Early unexpected exit" で落ちることを実測したため (2026-08-16、iOS 26.0 sim)。
# -p 2 以上を使う時は DESTINATION_SIM_NAME で worktree ごとに専用シミュレータを分けても
# 同一シミュレータ内の並列は解決しない点に注意 (リトライで補完される)
PARALLEL=1
while [[ $# -gt 0 ]]; do
  case $1 in
    -l|--languages)
      LANGUAGES="$2"
      shift 2
      ;;
    -n|--numbers)
      SCREENSHOT_NUMBERS="$2"
      shift 2
      ;;
    -d|--devices)
      DEVICES="$2"
      shift 2
      ;;
    -p|--parallel)
      PARALLEL="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --overwrite)
      OVERWRITE=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -l LANGS           実行する言語をカンマ区切りで指定 (例: \"ja,en\", デフォルト: 全言語)"
      echo "  -n NUMS            実行するスクリーンショット番号を指定 (例: \"1,2,3\" or \"1-6\", デフォルト: 全番号)"
      echo "  -d DEVICES         撮影デバイス (表示サイズ) をカンマ区切りで指定 (69: 6.9インチ iPhone 17 Pro Max, 65: 6.5インチ iPhone 13 Pro Max, duo-outer / duo-inner: iPhone Duo の外側 / 内側ディスプレイ。デフォルト: $SCREENSHOT_DEVICES)"
      echo "  -p NUM             並列実行数を指定 (デフォルト: 1。同一シミュレータでの並列はランナーが落ちやすい)"
      echo "  --skip-build       build-for-testing をスキップ"
      echo "  --overwrite        既存スクリーンショットを上書き（デフォルト: 全言語分揃っていればスキップ）"
      echo "  -h, --help         このヘルプメッセージを表示"
      echo ""
      echo "Examples:"
      echo "  # 全言語・全番号で生成"
      echo "  $0"
      echo ""
      echo "  # スクショ1のみ、日本語のみ"
      echo "  $0 -n \"1\" -l \"ja\""
      echo ""
      echo "  # ビルドスキップして逐次実行"
      echo "  $0 --skip-build -p 1"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# 撮影 (ビルド・UITest 実行) には iOS 26 系ランタイムが必須。env 側は apply_variant.sh など
# 撮影しない経路からも source されるため必須にせず、撮影の入口で検査する。
# --help はランタイム不在の環境でも表示できるよう、オプション解析より後に置く。
# iPhone Duo だけを撮る時は iOS 26 系は要らず、代わりに 27.1 以上を検査する (デバイス一覧の検証の後)
if [ -z "$SCREENSHOT_OS_VERSION" ] && ! [[ "$DEVICES" =~ ^[[:space:]]*duo-(outer|inner)([[:space:]]*,[[:space:]]*duo-(outer|inner))*[[:space:]]*$ ]]; then
  echo "Error: 利用可能な iOS 26 系の simulator ランタイムが見つかりません (xcrun simctl list runtimes available で確認してください)" >&2
  exit 1
fi

# ログファイルの設定
# fd 3 にコンソール出力を保存し、stdout/stderr はログファイルへリダイレクト
exec 3>&1 4>&2
LOG_DIR="$(pwd)/tmp"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/generate_appstore_screenshots.$(date +%Y%m%d_%H%M%S).logs.txt"
exec >"$LOG_FILE" 2>&1
echo "Log file: $LOG_FILE" >&3

# 進行ログを見やすく (コンソールとログファイルの両方に出す)
sep() {
  printf '\n==== %s ====\n' "$*"
  printf '==== %s ====\n' "$*" >&3
}

# スクリーンショット番号でテストファイルをフィルタリングする関数
# カンマ区切り（"1,2,3"）と範囲指定（"1-6"）の混在に対応
filter_test_files() {
  local numbers=$1
  local all_files=$2
  local filtered=""

  IFS=',' read -ra parts <<< "$numbers"
  for part in "${parts[@]}"; do
    if [[ "$part" == *-* ]]; then
      # 範囲指定（例: "1-6"）
      local start=${part%-*}
      local end=${part#*-}
      for ((i=start; i<=end; i++)); do
        local match
        match=$(echo "$all_files" | grep "AppStoreScreenshot${i}PageSnapshotUITest.swift" || true)
        [ -n "$match" ] && filtered+="$match"$'\n'
      done
    else
      # 単一番号
      local match
      match=$(echo "$all_files" | grep "AppStoreScreenshot${part}PageSnapshotUITest.swift" || true)
      [ -n "$match" ] && filtered+="$match"$'\n'
    fi
  done

  echo "$filtered" | sort -u | grep -v '^$'
}

# テストのスクリーンショットが全言語分揃っているかチェックする関数
# 全ファイルが存在する場合は 0（true）を返す
is_test_complete() {
  local test_file=$1
  local filename=$(basename "$test_file" .swift)
  local screenshot_number=$(echo "$filename" | sed -E 's/AppStoreScreenshot([0-9]+)PageSnapshotUITest/\1/')
  local variant_name=$(get_variant_name "$screenshot_number")
  local variant_index=$(get_variant_index "$screenshot_number")
  local expected_file="${variant_index}_${SCREENSHOT_DISPLAY_TYPE}_${variant_index}.png"

  # 対象言語リストを決定 (未指定時の全言語は AppStoreScreenshotsUITests/Languages.swift と揃える)
  local target_languages
  if [ -n "$LANGUAGES" ]; then
    IFS=',' read -ra target_languages <<< "$LANGUAGES"
  else
    target_languages=(ja en)
  fi

  for lang in "${target_languages[@]}"; do
    lang=$(echo "$lang" | tr -d ' ')
    local fastlane_lang=$(map_language_to_fastlane "$lang")
    local output_file="$VARIANT_OUTPUT_BASE_DIR/_variant-${variant_name}/${fastlane_lang}/${expected_file}"
    if [ ! -f "$output_file" ]; then
      return 1
    fi
  done
  return 0
}

# --overwrite 時に、対象テストの既存出力 (対象言語分) を削除する関数。
# 古い出力が残っていると、テストが失敗しても is_test_complete が前回の生成物で
# 成功と誤判定するため、実行前に消して今回の生成物だけで成否を判定できるようにする
remove_test_outputs() {
  local test_file=$1
  local filename=$(basename "$test_file" .swift)
  local screenshot_number=$(echo "$filename" | sed -E 's/AppStoreScreenshot([0-9]+)PageSnapshotUITest/\1/')
  local variant_name=$(get_variant_name "$screenshot_number")
  local variant_index=$(get_variant_index "$screenshot_number")
  local expected_file="${variant_index}_${SCREENSHOT_DISPLAY_TYPE}_${variant_index}.png"

  local target_languages
  if [ -n "$LANGUAGES" ]; then
    IFS=',' read -ra target_languages <<< "$LANGUAGES"
  else
    target_languages=(ja en)
  fi

  for lang in "${target_languages[@]}"; do
    lang=$(echo "$lang" | tr -d ' ')
    local fastlane_lang=$(map_language_to_fastlane "$lang")
    rm -f "$VARIANT_OUTPUT_BASE_DIR/_variant-${variant_name}/${fastlane_lang}/${expected_file}"
  done
}

# 1つのテストを実行して抽出・整理する関数（並列実行の単位）
run_single_test() {
  local test_file=$1
  local test_count=$2
  local total_count=$3
  local temp_dir=$4

  sep "Processing test $test_count/$total_count: $test_file"

  # テスト実行パスと artifact パスを取得
  local test_path artifact_path
  read -r test_path artifact_path <<< "$(get_test_info "$test_file")"

  sep "Test path: $test_path"
  sep "Artifact path: $artifact_path"

  # テストごとにユニークな一時ディレクトリを使用（並列実行の競合回避）
  local test_temp_dir="${temp_dir}/$(basename "$test_file" .swift)"
  rm -rf "$test_temp_dir"
  mkdir -p "$test_temp_dir"

  # テスト実行。ホスト側で撮るデバイス (iPhone Duo の外側・内側) では、画像と manifest.json を
  # 一時ディレクトリに直接書かせ、xcresult からの抽出を飛ばす
  local host_capture_dir=""
  if is_host_capture_device "$SCREENSHOT_DEVICE"; then
    host_capture_dir="$(pwd)/$test_temp_dir"
  fi
  ./scripts/generate_screenshots/run_appstore_screenshot.sh "$test_path" "$artifact_path" "$LANGUAGES" "$host_capture_dir" || true

  # テスト実行直後にスクリーンショットを抽出・整理
  if [ -d "$artifact_path" ]; then
    sep "Extracting screenshots: $artifact_path"

    # xcresulttool で Attachment を抽出 (ホスト撮影では manifest.json が既に一時ディレクトリにある)
    if [ -z "$host_capture_dir" ]; then
      xcrun xcresulttool export attachments \
        --path "$artifact_path" \
        --output-path "$test_temp_dir" || true
    fi

    # fastlane 形式に整理
    sep "Organizing screenshots to fastlane format"
    ./scripts/generate_screenshots/organize_appstore_screenshots.sh "$test_temp_dir" || true

    # 成功マーカーを作成（リトライ判定用）。
    # テストが失敗しても結果バンドル (artifact ディレクトリ) は作られるため、
    # ディレクトリの存在ではなく「対象言語分の出力が実際に揃ったか」で成功を判定する
    if is_test_complete "$test_file"; then
      touch "${temp_dir}/.success_${SCREENSHOT_DEVICE}_$(basename "$test_file" .swift)"
    fi

  else
    echo "Warning: Artifact not found: $artifact_path" >&3
  fi

  # テストごとの一時ディレクトリを削除
  rm -rf "$test_temp_dir"
}

# 一時ディレクトリの準備
TEMP_SCREENSHOTS_DIR="scripts/generate_screenshots/temp_screenshots"
mkdir -p "$TEMP_SCREENSHOTS_DIR"

# 言語フィルタリング設定のログ出力
if [ -n "$LANGUAGES" ]; then
  sep "Languages: $LANGUAGES"
fi

# デバイス (表示サイズ) 一覧の検証。未対応の区分は撮影前に落とす
IFS=',' read -ra device_list <<< "$DEVICES"
device_list=($(printf '%s\n' "${device_list[@]}" | tr -d ' ' | grep -v '^$'))
if [ "${#device_list[@]}" -eq 0 ]; then
  echo "Error: -d に撮影デバイスが指定されていません" >&3
  exit 1
fi
uses_duo=false
# 起動した iPhone Duo の UDID (prepare_duo_simulator が設定し、終了時の後片付けが参照する)
duo_udid=""
for device in "${device_list[@]}"; do
  if ! get_display_type "$device" > /dev/null 2>&1; then
    echo "Error: 未対応の撮影デバイスです: $device (対応: 69, 65, duo-outer, duo-inner)" >&3
    exit 1
  fi
  if [ -n "$(get_duo_pose "$device")" ]; then
    uses_duo=true
  fi
done
# 専用シミュレータ名は 1 機種分にしか付けられない (別機種を同名では作れない) ため、複数機種との併用は拒否する。
# duo-outer と duo-inner は同じ機種 (iPhone Duo) の姿勢違いなので、この 2 つだけの組は 1 機種として許す
device_type_count=$(printf '%s\n' "${device_list[@]}" | while read -r d; do get_device_type_name "$d"; done | sort -u | wc -l | tr -d ' ')
if [ -n "${DESTINATION_SIM_NAME:-}" ] && [ "$device_type_count" -gt 1 ]; then
  echo "Error: DESTINATION_SIM_NAME を使う時は -d で撮影デバイスを 1 機種に絞ってください (指定: $DEVICES)" >&3
  exit 1
fi
# iPhone Duo の撮影の前提: iOS 27.1 以上のランタイムと、姿勢を切り替える duo-pose.sh (ローカルの Mac の Device Hub を操作する)
if [ "$uses_duo" = true ]; then
  if [ -z "$SCREENSHOT_DUO_OS_VERSION" ]; then
    echo "Error: iPhone Duo の撮影には iOS 27.1 以上の simulator ランタイムが必要です (xcrun simctl list runtimes available で確認してください)" >&3
    exit 1
  fi
  if [ ! -x "$DUO_POSE_SCRIPT" ]; then
    echo "Error: iPhone Duo の姿勢を切り替えるスクリプトがありません: $DUO_POSE_SCRIPT (ios-simulator skill の scripts/duo-pose.sh)" >&3
    exit 1
  fi
  if ! command -v magick > /dev/null 2>&1; then
    echo "Error: iPhone Duo の内側ディスプレイの撮影には magick (ImageMagick) が必要です。brew install imagemagick" >&3
    exit 1
  fi
fi
sep "Devices: ${device_list[*]}"

# iPhone Duo の simulator を起動し、デバイス区分に応じた姿勢 (閉じた = 外側、開いた = 内側) に切り替える関数。
# 姿勢の切り替えは Booted の simulator にしか効かないため、xcodebuild の前に起動しておく。
# 起動直後は有効なディスプレイを判定できず duo-pose.sh が STATUS=ERROR を返すことがあるため、数秒おいて再試行する
# (references/iphone-duo.md の 3)
prepare_duo_simulator() {
  local pose
  pose=$(get_duo_pose "$SCREENSHOT_DEVICE")
  [ -n "$pose" ] || return 0

  local udid
  udid=$(resolve_simulator_udid "$DESTINATION_SIM_RESOLVED_NAME" "$SCREENSHOT_DEVICE_OS_VERSION")
  if [ -z "$udid" ]; then
    echo "Error: iPhone Duo の simulator '$DESTINATION_SIM_RESOLVED_NAME' (iOS $SCREENSHOT_DEVICE_OS_VERSION) の UDID を解決できません" >&3
    return 1
  fi
  # 終了時の後片付け用に控える。最後に撮ったデバイスが Duo 以外 (-d "duo-inner,69" 等) でも、起動した Duo を特定して閉じて停止するため
  duo_udid="$udid"
  sep "Booting iPhone Duo simulator: $udid"
  # 起動済みなら boot は失敗するが、その状態で続けてよい
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b

  sep "Setting iPhone Duo pose: $pose"
  local attempt
  for attempt in 1 2 3 4 5; do
    if bash "$DUO_POSE_SCRIPT" set --udid "$udid" "$pose"; then
      return 0
    fi
    echo "duo-pose.sh が失敗しました (試行 $attempt/5)。5 秒後に再試行します"
    sleep 5
  done
  echo "Error: iPhone Duo の姿勢を $pose にできません (duo-pose.sh の出力はログファイルを参照)" >&3
  return 1
}

# 最初のデバイスでシミュレータを用意してビルドする。
# build-for-testing の成果物は simulator SDK 共通で、他デバイスの test-without-building にもそのまま使える
# (iOS 27.1 の iPhone Duo で test-without-building する時も同じ成果物でよい。本 PR で実測)
configure_screenshot_device "${device_list[0]}"

# シミュレータが存在しない場合は自動作成
ensure_simulator_exists

# ビルド
if [ "$SKIP_BUILD" = false ]; then
  rm -rf artifacts/appstore_screenshots
  sep "Building AppStore Screenshot Tests"
  ./scripts/generate_screenshots/build_appstore_screenshot.sh
else
  sep "Skipping build (--skip-build specified)"
fi

# AppStoreScreenshot テストファイルのみを検索
sep "Collecting AppStore screenshot test files"
test_files=$(find AppStoreScreenshotsUITests/Features/AppStoreScreenshot \
  -type f -name "*SnapshotUITest.swift" 2>/dev/null | sort)

if [ -z "$test_files" ]; then
  echo "Error: No AppStoreScreenshot test files found in AppStoreScreenshotsUITests/Features/AppStoreScreenshot/" >&3
  exit 1
fi

# -n オプションが指定されていればフィルタリング
if [ -n "$SCREENSHOT_NUMBERS" ]; then
  sep "Filtering by screenshot numbers: $SCREENSHOT_NUMBERS"
  test_files=$(filter_test_files "$SCREENSHOT_NUMBERS" "$test_files")

  if [ -z "$test_files" ]; then
    echo "Error: No test files match the specified numbers: $SCREENSHOT_NUMBERS" >&3
    exit 1
  fi
fi

total_count=$(echo "$test_files" | wc -l | tr -d ' ')
sep "Found $total_count AppStore screenshot test(s), running with $PARALLEL parallel job(s)"

# 1 デバイス分の全テスト実行 (並列実行 → 失敗分の逐次リトライ) を行う関数。
# 成否は成功マーカー (.success_{device}_{test}) で記録し、最後にデバイス横断で集計する
run_all_tests_for_device() {
  local device=$1
  configure_screenshot_device "$device"
  sep "Device: $device ($SCREENSHOT_DEVICE_TYPE, $SCREENSHOT_DISPLAY_TYPE)"

  # シミュレータが存在しない場合は自動作成 (2 台目以降のデバイスはここで用意する)
  ensure_simulator_exists

  # iPhone Duo は起動して姿勢を合わせてから撮る (失敗したら、このデバイスの全テストを未成功のまま次へ進める)
  if ! prepare_duo_simulator; then
    return 0
  fi

  # 並列実行ループ
  # 並列数の制御は PID を FIFO で待つ方式にする (macOS 標準の Bash 3.2 には wait -n が無く、
  # `wait -n || true` は失敗が握り潰されて実際には待機しないため)
  job_pids=()
  test_count=0
  for test_file in $test_files; do
    test_count=$((test_count + 1))

    # --overwrite の場合は既存出力を先に削除し、今回の生成物だけで成否を判定する
    if [ "$OVERWRITE" = true ]; then
      remove_test_outputs "$test_file"
    fi

    # --overwrite でない場合、全言語分のファイルが揃っていればスキップ
    if [ "$OVERWRITE" = false ] && is_test_complete "$test_file"; then
      sep "Skipping test $test_count/$total_count (already complete): $(basename "$test_file")"
      continue
    fi

    run_single_test "$test_file" "$test_count" "$total_count" "$TEMP_SCREENSHOTS_DIR" &
    job_pids+=($!)

    # 並列数上限に達したら最も古いジョブの完了を待つ
    if [ "${#job_pids[@]}" -ge "$PARALLEL" ]; then
      wait "${job_pids[0]}" 2>/dev/null || true
      job_pids=(${job_pids[@]+"${job_pids[@]:1}"})
    fi
  done

  # 残りのバックグラウンドジョブ完了を待つ
  wait 2>/dev/null || true

  # 失敗テストの検出とリトライ
  failed_tests=""
  for test_file in $test_files; do
    marker="${TEMP_SCREENSHOTS_DIR}/.success_${SCREENSHOT_DEVICE}_$(basename "$test_file" .swift)"
    if [ ! -f "$marker" ]; then
      failed_tests+="$test_file"$'\n'
    fi
  done
  failed_tests=$(echo "$failed_tests" | grep -v '^$' || true)

  if [ -n "$failed_tests" ]; then
    failed_count=$(echo "$failed_tests" | wc -l | tr -d ' ')
    sep "Retrying $failed_count failed test(s) sequentially"

    retry_count=0
    for test_file in $failed_tests; do
      retry_count=$((retry_count + 1))

      # リトライ前にもう一度チェック（他のテストの副作用等で揃っている可能性）
      if [ "$OVERWRITE" = false ] && is_test_complete "$test_file"; then
        sep "Skipping retry $retry_count/$failed_count (already complete): $(basename "$test_file")"
        # リトライ不要なのでsuccessマーカーを作成
        touch "${TEMP_SCREENSHOTS_DIR}/.success_${SCREENSHOT_DEVICE}_$(basename "$test_file" .swift)"
        continue
      fi

      run_single_test "$test_file" "$retry_count" "$failed_count" "$TEMP_SCREENSHOTS_DIR"
    done
  fi
}

for device in "${device_list[@]}"; do
  run_all_tests_for_device "$device"
done

# 最終的な失敗テストの確認 (全デバイス横断)
final_failed=""
for device in "${device_list[@]}"; do
  for test_file in $test_files; do
    marker="${TEMP_SCREENSHOTS_DIR}/.success_${device}_$(basename "$test_file" .swift)"
    if [ ! -f "$marker" ]; then
      final_failed+="  - [$device] $(basename "$test_file")"$'\n'
    fi
  done
done

# 一時ファイル・ディレクトリの最終クリーンアップ
cleanup_temp_files

# リトライ後も出力が揃わなかったテストがある場合は、欠落した一式を正常な素材として
# 後続処理 (apply_variant / fastlane) に渡さないよう非ゼロで終了する
if [ -n "$final_failed" ]; then
  sep "ERROR: The following tests failed even after retry:"
  echo "$final_failed" >&3
  echo "$final_failed"
  echo "ログファイル: $LOG_FILE" >&3
  cleanup_duo_simulator
  exit 1
fi

cleanup_duo_simulator

sep "All done."
sep "App Store screenshots saved to: $VARIANT_OUTPUT_BASE_DIR/_variant-*/"
echo ""
echo "" >&3
echo "利用可能なバリアント:"
echo "利用可能なバリアント:" >&3
ls -d "$VARIANT_OUTPUT_BASE_DIR"/_variant-* 2>/dev/null | sed 's|.*/_variant-||' | while read v; do
  echo "  - $v"
  echo "  - $v" >&3
done
echo ""
echo "" >&3
echo "選択バリアントを適用:"
echo "選択バリアントを適用:" >&3
echo "  ./scripts/generate_screenshots/apply_variant.sh <variant-name>"
echo "  ./scripts/generate_screenshots/apply_variant.sh <variant-name>" >&3
echo ""
echo "" >&3
echo "ログファイル: $LOG_FILE"
echo "ログファイル: $LOG_FILE" >&3
