#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT_DIR="$SCRIPT_DIR/../../"
cd "$PROJECT_ROOT_DIR"

source scripts/snapshot_ui_tests/snapshot_ui_test_env.sh

echo "==== Building SnapshotUITests ===="
# LicenseList の build tool plugin (PrepareLicenseList) はダイアログでの信頼が必要で、非対話環境では検証に失敗する。
# ローカル実測では -skipPackagePluginValidation 単独・-skipMacroValidation 単独では通らず、両方を渡した時だけビルドできた
xcodebuild build-for-testing \
  -project MementoMorning.xcodeproj \
  -scheme "$SCHEME" \
  -destination "$DESTINATION"  \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -skipPackagePluginValidation \
  -skipMacroValidation

echo "==== Build completed ===="
