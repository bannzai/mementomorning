#!/bin/bash
# DEBUG 限定の疑似録画モード (issue #52) が「録画結果」として返すフィクスチャ動画を生成する。
# 生成物 (MementoMorning/Features/MorningQuestion/DebugVideoAnswerFixture_{en,ja}.mov) はリポジトリに
# コミット済みで、通常の開発では再生成不要。発話内容を変えたい時だけ本スクリプトを実行して差し替える。
#
# 英語版と日本語版を作るのは、シミュレータには端末の言語のオンデバイス音声認識アセットしか入って
# おらず、言語が違うと文字起こしが kLSRErrorDomain 101 (No Assistant asset for language ...) で
# 失敗するため (iOS 26.5 simulator で実測)。アプリ側は Locale.current の言語で使う方を選ぶ。
#
# 発話 (UTTERANCE_*) は文字起こし (VideoAnswerTranscriber) の検証で期待値として使う。
# QA が「何が回答テキストになるはずか」を照合できるよう、発話内容の SSOT を本スクリプトに置き、
# DebugVideoAnswerFixture.swift の定数と同じ文言に保つ。
set -euo pipefail

# 発話内容 (文字起こしの期待値)
UTTERANCE_EN="I want to see the ocean with my family today."
UTTERANCE_JA="今日は家族と海を見に行きたい"

cd "$(dirname "$0")/.."
OUTPUT_DIR="MementoMorning/Features/MorningQuestion"
WORK_DIR="./tmp/video_answer_fixture"

for command in say ffmpeg; do
  command -v "$command" > /dev/null || { echo "Error: $command が見つかりません" >&2; exit 1; }
done

mkdir -p "$WORK_DIR"

# 引数: 言語コード / say に渡す音声名 / 発話内容
generate_fixture() {
  language_code="$1"
  voice="$2"
  utterance="$3"
  output="$OUTPUT_DIR/DebugVideoAnswerFixture_$language_code.mov"

  # 音声トラック。macOS 標準の音声合成で、既知の発話を含む AIFF を作る
  say -v "$voice" -o "$WORK_DIR/utterance-$language_code.aiff" "$utterance"

  # 映像トラック。疑似録画では画面に出さない (プレビューは黒のまま) ため、
  # 内容ではなくファイルサイズを優先して墨色 (デザイントークンの ink) の単色にする。
  # 360x640 はアプリの縦向き固定に合わせた縦長で、コミットするフィクスチャとして十分小さい
  ffmpeg -y -loglevel error \
    -f lavfi -i "color=c=0x111111:s=360x640:r=30" \
    -i "$WORK_DIR/utterance-$language_code.aiff" \
    -shortest -c:v libx264 -pix_fmt yuv420p -c:a aac -b:a 64k \
    "$output"

  echo "generated: $output"
  echo "  utterance: $utterance"
  ls -lh "$output"
}

generate_fixture en Samantha "$UTTERANCE_EN"
generate_fixture ja Kyoko "$UTTERANCE_JA"
