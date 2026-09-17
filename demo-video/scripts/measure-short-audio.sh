#!/usr/bin/env bash
set -euo pipefail

# 縦動画の音の流れを区間ごとの平均音量 (dB) で確認する (issue #167)。
# 期待: 0〜6.7 アラーム音、8.2〜15.2 声 (アラームは小さく)、15.2〜15.5 無音、15.5〜18.2 チャイム、18.2〜19.8 無音
# 区間の秒数は build-shorts.py のタイムライン定数に合わせる (WAKE_LEN 等を変えたらここも直す)
#
# 使い方: bash demo-video/scripts/measure-short-audio.sh <mp4>
# 出力: 区間 \t 平均音量 (mean_volume) の一覧

MP4="${1:?mp4 が必要}"
command -v ffmpeg >/dev/null || { echo "ERROR: ffmpeg が必要です" >&2; exit 1; }

measure() {
    local start="$1" end="$2" label="$3"
    local mean
    mean=$(ffmpeg -nostdin -v info -ss "$start" -to "$end" -i "$MP4" -vn -af volumedetect -f null - 2>&1 \
        | awk -F': ' '/mean_volume/ { print $2 }')
    printf '%s\t%s\n' "$label" "${mean:-n/a}"
}

measure 0.0 6.7 "0.0-6.7 wake+alarm"
measure 6.7 8.2 "6.7-8.2 question+alarm"
measure 8.2 9.7 "8.2-9.7 record (alarm ducking)"
measure 9.7 14.2 "9.7-14.2 speech"
measure 14.2 15.2 "14.2-15.2 alarm low"
measure 15.2 15.5 "15.2-15.5 silence beat"
measure 15.5 18.2 "15.5-18.2 calendar+chime"
measure 18.2 19.8 "18.2-19.8 brand"
