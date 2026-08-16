#!/bin/bash
#
# simulator_common.sh
#
# スクリーンショット生成系スクリプト (generate_screenshots / snapshot_ui_tests) が共有する
# シミュレータ関連の共通関数。各 env スクリプトから source して使用する。
#

# DESTINATIONで指定されたシミュレータが存在しない場合に自動作成する関数
# DESTINATIONからシミュレータ名とOSバージョンを抽出し、
# xcrun simctl を使ってシミュレータの存在確認・作成を行う
ensure_simulator_exists() {
  local sim_name
  sim_name=$(echo "$DESTINATION" | sed -E 's/.*name=([^,]+).*/\1/')
  local os_version
  os_version=$(echo "$DESTINATION" | sed -E 's/.*OS=([^,]+).*/\1/')

  echo "シミュレータ確認: name=${sim_name}, OS=${os_version}"

  # 該当シミュレータが存在するか確認。
  # 同名デバイスが別の iOS ランタイムにだけ存在するケースを「存在する」と誤判定しないよう、
  # simctl の検索語で対象 OS のランタイム区分に絞ってから名前を照合する。
  # grep -q は最初のマッチで早期終了し、出力の多い環境では simctl 側が SIGPIPE で非0終了する。
  # 呼び出し元スクリプトが set -o pipefail のためパイプ全体が失敗扱いになり、
  # 既存シミュレータを「存在しない」と誤判定して重複作成してしまうので -q は使わない
  if xcrun simctl list devices "iOS ${os_version}" | grep "${sim_name} (" > /dev/null; then
    echo "シミュレータ '${sim_name}' は既に存在します。作成をスキップします。"
    return 0
  fi

  echo "シミュレータ '${sim_name}' が見つかりません。自動作成します。"

  # デバイスタイプIDを取得
  # DESTINATION_SIM_NAME で「issue-13-13PM」のような専用名を使う場合、
  # 専用名はデバイスタイプ名と一致しないため、検索には DESTINATION_SIM_DEVICE_TYPE
  # (未指定時は iPhone 13 Pro Max) を使う。スペースをハイフンに変換して検索する
  local device_type_name="${DESTINATION_SIM_DEVICE_TYPE:-iPhone 13 Pro Max}"
  local device_type_search
  device_type_search=$(echo "$device_type_name" | tr ' ' '-')
  local device_type_id
  device_type_id=$(xcrun simctl list devicetypes | grep -i "$device_type_search" | head -1 | sed -E 's/.*\(([^)]+)\).*/\1/')

  if [ -z "$device_type_id" ]; then
    echo "エラー: デバイスタイプ '${device_type_name}' が見つかりません。" >&2
    echo "利用可能なデバイスタイプ:" >&2
    xcrun simctl list devicetypes | grep -i "iPhone" >&2
    return 1
  fi
  echo "デバイスタイプID: ${device_type_id}"

  # ランタイムIDを取得
  local runtime_id
  runtime_id=$(xcrun simctl list runtimes | grep "iOS ${os_version}" | head -1 | awk '{print $NF}')

  if [ -z "$runtime_id" ]; then
    echo "エラー: iOS ${os_version} ランタイムが見つかりません。" >&2
    echo "利用可能なランタイム:" >&2
    xcrun simctl list runtimes | grep "iOS" >&2
    return 1
  fi
  echo "ランタイムID: ${runtime_id}"

  # シミュレータを作成
  echo "シミュレータを作成中: xcrun simctl create \"${sim_name}\" ${device_type_id} ${runtime_id}"
  xcrun simctl create "${sim_name}" "${device_type_id}" "${runtime_id}"

  echo "シミュレータ '${sim_name}' を作成しました。"
}
