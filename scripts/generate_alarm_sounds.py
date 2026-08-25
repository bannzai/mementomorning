#!/usr/bin/env python3
"""アラーム音源 (MementoMorning/Shared/AlarmSounds/*.caf) を生成する。

外部のフリー音源はライセンス確認と出典管理が必要になるため、
本アプリのアラーム音は本スクリプトで合成したオリジナル音源 (ライセンス問題なし) を使う。
音色は「静かな世界観」(documents/PROJECT.md) に合わせ、ベル・チャイム系の減衰音で構成する。

再実行しても同じ入力 (合成パラメータ) から同じ音源を再生成するだけで冪等。
生成物は git 管理し、Xcode プロジェクトへの登録は project.pbxproj で行う。

使い方:
    python3 scripts/generate_alarm_sounds.py

依存: macOS 標準の afconvert (WAV -> CAF 変換)
"""

import math
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

# 44.1kHz / 16bit mono。アラーム音は帯域の広さより互換性を優先する
SAMPLE_RATE = 44100
# 1 ファイルの長さ (秒)。システムがループ再生する前提で、末尾が無音に減衰する長さにする
DURATION_SECONDS = 6.0

# 出力先。アプリターゲットのリソースとしてバンドルされる
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "MementoMorning" / "Shared" / "AlarmSounds"


def bell_strike(samples: list, start_seconds: float, base_frequency: float, partials: list, decay_seconds: float, amplitude: float) -> None:
    """samples へベルの一打を加算合成する。

    partials は (周波数倍率, 相対振幅) のリスト。チューブラーベル系の非整数倍音で金属的な響きを作る。
    エンベロープは打撃音らしい指数減衰
    """
    start_index = int(start_seconds * SAMPLE_RATE)
    strike_length = int(decay_seconds * 4 * SAMPLE_RATE)
    for i in range(strike_length):
        index = start_index + i
        if index >= len(samples):
            break
        t = i / SAMPLE_RATE
        envelope = math.exp(-t / decay_seconds)
        value = 0.0
        for ratio, partial_amplitude in partials:
            # 高い部分音ほど早く減衰させると自然な金属音になる
            value += partial_amplitude * math.exp(-t * ratio / (decay_seconds * 2)) * math.sin(2 * math.pi * base_frequency * ratio * t)
        samples[index] += amplitude * envelope * value


def soft_pulse(samples: list, start_seconds: float, frequency: float, pulse_seconds: float, amplitude: float) -> None:
    """samples へ柔らかい正弦波パルス (マリンバ調) を加算合成する。

    アタック 10ms で角を取り、残りは指数減衰させてクリックノイズを避ける
    """
    start_index = int(start_seconds * SAMPLE_RATE)
    pulse_length = int(pulse_seconds * SAMPLE_RATE)
    attack_length = int(0.010 * SAMPLE_RATE)
    for i in range(pulse_length):
        index = start_index + i
        if index >= len(samples):
            break
        t = i / SAMPLE_RATE
        if i < attack_length:
            envelope = i / attack_length
        else:
            envelope = math.exp(-(t - attack_length / SAMPLE_RATE) / (pulse_seconds / 4))
        # 基音 + 弱いオクターブ上で丸い音にする
        value = math.sin(2 * math.pi * frequency * t) + 0.3 * math.sin(2 * math.pi * frequency * 2 * t)
        samples[index] += amplitude * envelope * value


def render_gentle_chime() -> list:
    """やわらかなチャイム。A5 のチューブラーベルを 1.5 秒間隔で 4 打"""
    samples = [0.0] * int(DURATION_SECONDS * SAMPLE_RATE)
    # チューブラーベルの代表的な部分音比 (1 : 2.76 : 5.40)
    partials = [(1.0, 1.0), (2.76, 0.4), (5.40, 0.15)]
    for strike_index in range(4):
        bell_strike(samples, start_seconds=strike_index * 1.5, base_frequency=880.0, partials=partials, decay_seconds=1.0, amplitude=0.35)
    return samples


def render_morning_bell() -> list:
    """朝の鐘。C5 の深いベルを 2 秒間隔で 3 打"""
    samples = [0.0] * int(DURATION_SECONDS * SAMPLE_RATE)
    partials = [(1.0, 1.0), (2.0, 0.5), (2.76, 0.3), (4.07, 0.1)]
    for strike_index in range(3):
        bell_strike(samples, start_seconds=strike_index * 2.0, base_frequency=523.25, partials=partials, decay_seconds=1.6, amplitude=0.4)
    return samples


def render_soft_pulse() -> list:
    """しずかなパルス。E5 の 2 連パルスを 1.5 秒周期で繰り返す"""
    samples = [0.0] * int(DURATION_SECONDS * SAMPLE_RATE)
    for cycle_index in range(4):
        cycle_start = cycle_index * 1.5
        soft_pulse(samples, start_seconds=cycle_start, frequency=659.26, pulse_seconds=0.5, amplitude=0.4)
        soft_pulse(samples, start_seconds=cycle_start + 0.25, frequency=659.26, pulse_seconds=0.5, amplitude=0.4)
    return samples


def render_silent() -> list:
    """無音。音を鳴らしたくないユーザー向けの選択肢 (AlarmKit に音を消す API が無いため無音音源で代替する)。

    長さはループしても無害な 1 秒にする
    """
    return [0.0] * SAMPLE_RATE


def write_caf(samples: list, output_path: Path) -> None:
    """samples (float -1.0..1.0) を WAV に書き出し、afconvert で CAF (16bit LE) へ変換する"""
    # クリッピング防止のためピークを 0.9 に正規化する (無音はそのまま)
    peak = max((abs(value) for value in samples), default=0.0)
    scale = 0.9 / peak if peak > 0 else 0.0
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_file:
        temp_wav_path = Path(temp_file.name)
    with wave.open(str(temp_wav_path), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for value in samples:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, value * scale)) * 32767))
        wav_file.writeframes(bytes(frames))
    subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16", str(temp_wav_path), str(output_path)], check=True)
    temp_wav_path.unlink()
    print(f"generated: {output_path}")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    write_caf(render_gentle_chime(), OUTPUT_DIR / "AlarmSoundGentleChime.caf")
    write_caf(render_morning_bell(), OUTPUT_DIR / "AlarmSoundMorningBell.caf")
    write_caf(render_soft_pulse(), OUTPUT_DIR / "AlarmSoundSoftPulse.caf")
    write_caf(render_silent(), OUTPUT_DIR / "AlarmSoundSilent.caf")


if __name__ == "__main__":
    main()
