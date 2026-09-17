#!/usr/bin/env bash
set -euo pipefail

# 縦動画の音の流れを区間ごとの平均音量 (dB) で確認する (issue #167)。
# 期待: 0〜4.5 アラーム音、6〜13 声 (アラームは小さく)、13.0〜13.3 無音、13.3〜16 チャイム、16〜17.6 無音
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

measure 0.0 4.5 "0.0-4.5 wake+alarm"
measure 4.5 6.0 "4.5-6.0 question+alarm"
measure 6.0 7.5 "6.0-7.5 record (alarm ducking)"
measure 7.5 12.0 "7.5-12.0 speech"
measure 12.0 13.0 "12.0-13.0 alarm low"
measure 13.0 13.3 "13.0-13.3 silence beat"
measure 13.3 16.0 "13.3-16.0 calendar+chime"
measure 16.0 17.6 "16.0-17.6 brand"
