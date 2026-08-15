#!/usr/bin/env bash
#
# generate_snapshot_ui_test_screenshots.sh
#
# 【目的】
# MementoMorningSnapshotUITests を実行し、全言語のスクリーンショットを取得するスクリプト。
# 日本語と他言語のスクリーンショットを比較して、翻訳の妥当性をチェックするために使用。
#
# 【使い方】
# 1. 全てのSnapshotUITestを実行:
#    $ ./scripts/snapshot_ui_tests/generate_snapshot_ui_test_screenshots.sh
#
# 2. 最初のN個のテストのみ実行 (デバッグ用):
#    $ ./scripts/snapshot_ui_tests/generate_snapshot_ui_test_screenshots.sh -n 5
#
# 3. X番目のテストから開始 (CI並列実行用):
#    $ ./scripts/snapshot_ui_tests/generate_snapshot_ui_test_screenshots.sh -b 10 -n 5
#
# 4. 特定のテストのみ実行 (CI並列実行用):
#    $ ./scripts/snapshot_ui_tests/generate_snapshot_ui_test_screenshots.sh -b 5 -n 1
#
# 5. ビルドをスキップして実行 (CI並列実行用):
#    $ ./scripts/snapshot_ui_tests/generate_snapshot_ui_test_screenshots.sh -b 2 -n 1 --skip-build
#
# 6. ヘルプを表示:
#    $ ./scripts/snapshot_ui_test/generate_snapshot_ui_test_screenshots.sh --help
#
# 【具体的な用途】
# - リリース前の多言語UIチェック
# - UI変更後の視覚的回帰テスト
# - 翻訳の妥当性検証用スクリーンショット生成
#
# 【動作】
# 1. MementoMorningSnapshotUITests/Features/**/*SnapshotUITest.swift を検索
# 2. build-for-testing でビルド
# 3. 各テストを test-without-building で実行 (-only-testing使用)
# 4. xcparse でスクリーンショットを抽出 (scripts/snapshot_ui_tests/screenshots/ に出力)
#
# 【注意事項】
# - Xcodeが必要
# - シミュレータが起動します
# - 実行には時間がかかる (テスト数 × 言語数 × 実行時間)
# - xcresulttoolを使用 (Xcodeに同梱)
#
set -euo pipefail

SCRIPT_DIR="$(cd `dirname $0` && pwd -P)"
PROJECT_ROOT_DIR=$SCRIPT_DIR/../../
cd $PROJECT_ROOT_DIR

source scripts/snapshot_ui_tests/snapshot_ui_test_env.sh

# Ctrl+C (SIGINT) でのクリーンアップ処理
cleanup() {
  echo ""
  echo "==== Interrupted by user (Ctrl+C) ===="
  echo "==== Cleaning up... ===="

  # 既に取得したスクリーンショットは保持
  if [ ${#artifact_paths[@]} -gt 0 ]; then
    echo "==== Extracting screenshots from completed tests ===="
    for artifact_path in "${artifact_paths[@]}"; do
      if [ -d "$artifact_path" ]; then
        echo "Extracting: $artifact_path"

        # manifest.json が既に存在する場合は削除
        if [ -f "scripts/snapshot_ui_tests/screenshots/manifest.json" ]; then
          rm -f scripts/snapshot_ui_tests/screenshots/manifest.json
        fi

        xcrun xcresulttool export attachments --path "$artifact_path" --output-path scripts/snapshot_ui_tests/screenshots/ || true
      fi
    done

    # スクリーンショットを整理
    echo "==== Organizing screenshots ===="
    ./scripts/snapshot_ui_tests/organize_screenshots.sh scripts/snapshot_ui_tests/screenshots/ || true

    echo "==== Partial screenshots saved to: scripts/snapshot_ui_tests/screenshots/ ===="
  fi

  echo "==== Exited ===="
  exit 130  # 128 + SIGINT(2)
}

# SIGINT (Ctrl+C) をトラップ
trap cleanup SIGINT

# オプション解析
MAX_TESTS=""
BEGIN_INDEX=1
SKIP_BUILD=false
LANGUAGES=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -n)
      MAX_TESTS="$2"
      shift 2
      ;;
    -b)
      BEGIN_INDEX="$2"
      shift 2
      ;;
    -l|--languages)
      LANGUAGES="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -b N               開始するテストのインデックス (1から開始, デフォルト: 1)"
      echo "  -n N               実行するテスト数 (デフォルト: 全て)"
      echo "  -l LANGS           実行する言語をカンマ区切りで指定 (例: \"ja,en\", デフォルト: 全言語)"
      echo "  --skip-build       build-for-testing をスキップ (CI並列実行で既にビルド済みの場合)"
      echo "  -h, --help         このヘルプメッセージを表示"
      echo ""
      echo "Examples:"
      echo "  # 全テスト実行"
      echo "  $0"
      echo ""
      echo "  # jaのみ実行"
      echo "  $0 -l \"ja\""
      echo ""
      echo "  # ja,enのみ実行"
      echo "  $0 -l \"ja,en\""
      echo ""
      echo "  # 2番目のテストから3個実行"
      echo "  $0 -b 2 -n 3"
      echo ""
      echo "  # 5番目のテストのみjaで実行"
      echo "  $0 -b 5 -n 1 -l \"ja\""
      echo ""
      echo "  # ビルドをスキップして実行 (CI並列実行用)"
      echo "  $0 -b 2 -n 1 --skip-build"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# 進行ログを見やすく
sep() { printf '\n==== %s ====\n' "$*"; }

sep "Preparing screenshots directory"
mkdir -p scripts/snapshot_ui_tests/screenshots

# シミュレータが存在しない場合は自動作成
ensure_simulator_exists

if [ "$SKIP_BUILD" = false ]; then
  rm -rf artifacts/snapshot_ui_test
  sep "Building SnapshotUITests"
  ./scripts/snapshot_ui_tests/build_snapshot_ui_test.sh
else
  sep "Skipping build (--skip-build specified)"
fi

sep "Collecting test files"
# MementoMorningSnapshotUITests/Features配下のテストファイルを取得
# Components配下も含める
all_test_files=$(find MementoMorningSnapshotUITests -type f -name "*SnapshotUITest.swift" | sort)
total_count=$(echo "$all_test_files" | wc -l | tr -d ' ')

# -b オプションで開始位置を調整
test_files=$(echo "$all_test_files" | tail -n +$BEGIN_INDEX)

# -n オプションが指定されている場合は制限
if [ -n "$MAX_TESTS" ]; then
  test_files=$(echo "$test_files" | head -n "$MAX_TESTS")
  end_index=$((BEGIN_INDEX + MAX_TESTS - 1))
  sep "Running tests $BEGIN_INDEX to $end_index (total: $total_count)"
else
  sep "Running tests from $BEGIN_INDEX to $total_count (total: $total_count)"
fi

# テストを実行してartifactを収集
test_count=0
artifact_paths=()

# set -e は無効化（テストが失敗しても継続）
set +e

for test_file in $test_files; do
  test_count=$((test_count + 1))
  current_index=$((BEGIN_INDEX + test_count - 1))
  sep "Processing test $current_index/$total_count: $test_file"

  # get_test_info でテスト実行パスとartifactパスを取得
  read -r test_path artifact_path <<< "$(get_test_info "$test_file")"

  sep "Test path: $test_path"
  sep "Artifact path: $artifact_path"
  
  # テストクラス名を取得 (例: AppSettingPageSnapshotUITest)
  test_class=$(basename "$test_file" .swift)
  screenshot_dir="scripts/snapshot_ui_tests/screenshots/$test_class"
  
  # 既にスクリーンショットディレクトリが存在する場合はスキップ
  if [ -d "$screenshot_dir" ]; then
    sep "Skipping test: $test_file (screenshots already exist in $screenshot_dir)"
    continue
  fi
  
  # スキップするテストファイルのリスト (撮影対象から外したいテストが出たらここに追加する)
  ignore_files=()

  # テストファイル名がスキップリストに含まれているかチェック
  # (bash 3.2 では set -u 下で空配列の "${arr[@]}" が unbound になるため ${arr[@]+...} でガードする)
  should_skip=false
  for ignore_file in ${ignore_files[@]+"${ignore_files[@]}"}; do
    if [[ "$test_file" == *"$ignore_file"* ]]; then
      should_skip=true
      sep "Skipping test: $test_file (matched ignore pattern: $ignore_file)"
      break
    fi
  done

  if [ "$should_skip" = true ]; then
    continue
  fi

  # テスト実行（言語指定がある場合は第3引数として渡す）
  ./scripts/snapshot_ui_tests/run_snapshot_ui_test.sh "$test_path" "$artifact_path" "$LANGUAGES"

  # テスト実行直後にスクリーンショット抽出
  if [ -d "$artifact_path" ]; then
    sep "Extracting screenshots immediately: $artifact_path"

    # manifest.json が既に存在する場合は削除
    if [ -f "scripts/snapshot_ui_tests/screenshots/manifest.json" ]; then
      rm -f scripts/snapshot_ui_tests/screenshots/manifest.json
    fi

    xcrun xcresulttool export attachments --path "$artifact_path" --output-path scripts/snapshot_ui_tests/screenshots/ || true

    # スクリーンショットを整理
    sep "Organizing screenshots"
    ./scripts/snapshot_ui_tests/organize_screenshots.sh scripts/snapshot_ui_tests/screenshots/ || true
  else
    echo "Warning: Artifact not found: $artifact_path"
  fi

  # artifactパスを配列に追加（cleanup用）
  artifact_paths+=("$artifact_path")
done

# テスト実行後は set -e を再有効化
set -e

sep "All done."
sep "Screenshots saved to: scripts/snapshot_ui_tests/screenshots/"
