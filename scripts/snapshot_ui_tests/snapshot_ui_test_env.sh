#!/bin/bash

export SCHEME="MementoMorningSnapshotUITests"
# App Store スクショ生成 (generate_screenshots) と同じデバイスを使い、シミュレータを増やさない
export DESTINATION="platform=iOS Simulator,name=${DESTINATION_SIM_NAME:-iPhone 13 Pro Max},OS=26.0"
export DERIVED_DATA_PATH=artifacts/snapshot_ui_test/derived_data

# テストファイルパスからテスト実行パスとartifactパスを取得する共通関数
# Usage: get_test_info <test_file_path>
# Returns: TEST_PATH ARTIFACT_PATH (space separated)
get_test_info() {
  local test_file=$1

  # ファイル名から .swift を除去
  local filename=$(basename "$test_file" .swift)

  # テスト実行パス: MementoMorningSnapshotUITests/{ClassName}/testSnapshot
  local test_path="MementoMorningSnapshotUITests/${filename}/testSnapshot"

  # Artifactパス: artifacts/snapshot_ui_test/{ClassName}/testSnapshot
  local artifact_path="artifacts/snapshot_ui_test/${filename}/testSnapshot"

  echo "$test_path $artifact_path"
}

# シミュレータの存在確認・自動作成 (ensure_simulator_exists) は共通関数を使う
source "$(dirname "${BASH_SOURCE[0]}")/../simulator_common.sh"
