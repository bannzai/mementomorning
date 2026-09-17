#!/usr/bin/env python3
"""TikTok / YouTube Shorts / X 用の縦動画 (issue #167) を ffmpeg で合成する。

構成 (約 17.6 秒、1080x1920、30fps。全編に 1 文のテロップを固定表示):
  0.0- 4.5  目を覚ます人物 (Veo 生成クリップ wake-<person>.mp4) + アラーム音
  4.5- 6.0  朝の問いの実画面 (全画面)。インカメラのプレビューに人物 (speak クリップ) を lighten 合成
  6.0-13.0  録画中の実画面。人物が答えを声に出す (speak クリップの音声)。アラーム音は声の下で小さくなり、録画停止で止まる
 13.0-13.3  黒 (無音の一拍)
 13.3-16.0  人生カレンダーの実画面 (全画面) + 静かな一音
 16.0-17.6  ブランドカード (中央)

使い方:
  python3 demo-video/scripts/build-shorts.py [--variant ID] [--lang en|ja]
  (省略時は config.shorts.json の全バリアント × 英日)

入力 (gitignore 対象。README の手順で用意する):
  demo-video/output/clips/morning-question.mp4  record-scene.sh で収録した朝の問い (1206x2622)
  demo-video/output/clips/calendar.mp4          同 カレンダー
  demo-video/output/shorts/motion/wake-<person>.mp4 / speak-<person>.mp4  generate-shorts-motion.py の出力
出力: demo-video/output/shorts/<variant>-<lang>.mp4 と同名 .png (1 秒 1 フレームのコンタクトシート)
冪等: 同じ入力から毎回同じ構成で作り直す (出力は上書き)
"""

import argparse
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = json.loads((ROOT / "config.shorts.json").read_text())
CLIPS = ROOT / "output/clips"
MOTION = ROOT / "output/shorts/motion"
OUT = ROOT / "output/shorts"
SOUNDS = ROOT.parent / "MementoMorning/Shared/AlarmSounds"
FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"

# 収録クリップのフレーム実測値 (2026-09-17 収録、fps=30 で CFR 化した経路で計測。再収録したら測り直す)
MQ_QUESTION_SHOWN = 2.2   # 問いと録画ボタンが表示され切った時刻
MQ_RECORD_START = 5.9     # 録画タイマー 0:00 の出現
CAL_GRID_SHOWN = 5.6      # 月グリッドが表示され切った時刻
# 人物の wake クリップの使い始め (冒頭に目が開いているフレームがある個体は飛ばす)
WAKE_IN = {"worker": 0.5, "student": 0.4, "creator": 0.4}

# タイムライン (秒)
WAKE_LEN = 4.5
QUESTION_LEN = 1.5
RECORD_LEN = 7.0
BEAT_LEN = 0.3
CAL_LEN = 2.7
BRAND_LEN = 1.6
T_QUESTION = WAKE_LEN
T_RECORD = T_QUESTION + QUESTION_LEN
T_BEAT = T_RECORD + RECORD_LEN
T_CAL = T_BEAT + BEAT_LEN
T_BRAND = T_CAL + CAL_LEN
TOTAL = T_BRAND + BRAND_LEN
SPEAK_IN = 0.5             # speak クリップの使い始め (発話は 2.0〜6.2 秒 → タイムラインでは T_RECORD+1.5 から)
T_ANSWER_SUB_START = T_RECORD + 2.0 - SPEAK_IN
T_ANSWER_SUB_END = T_RECORD + 6.4 - SPEAK_IN

# 収録クリップ (1206x2622) を 1080x1920 に敷き詰める。上 120px でステータスバーの時計を切り、下は「Answer in text」の
# リンクが切れる範囲で、問い・録画ボタン・タイマー・カレンダーは残る (録画ボタンは y≈1864 で下端ぎりぎり)。
# 問いの文字は y≈385〜502 に来るため、上部の固定テロップは y 136〜340 (フォント 52・3 行) に収めて重ねない
FULLBLEED = "fps=30,scale=1080:2348,crop=1080:1920:0:120,setsar=1"
# 人物をカメラプレビューに lighten 合成するとき、白い UI 文字が必ず残るよう人物側の輝度上限を下げる
PERSON = "fps=30,scale=1080:1920,setsar=1,colorlevels=romax=0.72:gomax=0.72:bomax=0.72"


def drawtext(textfile: Path, size: int, y: str, enable: str | None = None, box_alpha: float = 0.35) -> str:
    parts = [
        f"drawtext=fontfile='{FONT}'",
        f"textfile='{textfile}'",
        f"fontsize={size}",
        "fontcolor=white",
        "line_spacing=8",
        "x=(w-text_w)/2",
        f"y={y}",
        "shadowcolor=black@0.6",
        "shadowx=0",
        "shadowy=3",
        "box=1",
        f"boxcolor=black@{box_alpha}",
        "boxborderw=24",
    ]
    if enable:
        parts.append(f"enable='{enable}'")
    return ":".join(parts)


def build(variant: dict, lang: str, workdir: Path) -> Path:
    person = variant["person"]
    wake = MOTION / f"wake-{person}.mp4"
    speak = MOTION / f"speak-{person}.mp4"
    mq = CLIPS / "morning-question.mp4"
    cal = CLIPS / "calendar.mp4"
    for path in (wake, speak, mq, cal):
        if not path.exists():
            raise SystemExit(f"入力がありません: {path}")

    caption = workdir / f"caption-{variant['id']}-{lang}.txt"
    caption.write_text(variant["caption"][lang])
    answer = workdir / f"answer-{variant['id']}-{lang}.txt"
    answer.write_text(variant["answer_subtitle"][lang])
    brand = workdir / "brand.txt"
    brand.write_text("Memento Morning")
    tagline = workdir / f"tagline-{lang}.txt"
    tagline.write_text(CONFIG["brand_tagline"][lang])

    wake_in = WAKE_IN[person]
    alarm = SOUNDS / "AlarmSoundMorningBell.caf"
    chime = SOUNDS / "AlarmSoundGentleChime.caf"
    out = OUT / f"{variant['id']}-{lang}.mp4"

    # 入力: 0 wake, 1 speak, 2 mq, 3 cal, 4 alarm (loop), 5 chime
    filters = [
        # 1. 目を覚ます
        f"[0:v]trim=start={wake_in}:duration={WAKE_LEN},setpts=PTS-STARTPTS,fps=30,scale=1080:1920,setsar=1[wake]",
        # 2. 問いの実画面 + 人物 (発話前)
        f"[2:v]{FULLBLEED},trim=start={MQ_QUESTION_SHOWN}:duration={QUESTION_LEN},setpts=PTS-STARTPTS[q_ui]",
        f"[1:v]{PERSON},trim=start=0:duration={QUESTION_LEN},setpts=PTS-STARTPTS[q_person]",
        "[q_ui][q_person]blend=all_mode=lighten:shortest=1[question]",
        # 3. 録画中の実画面 + 人物 (発話)
        f"[2:v]{FULLBLEED},trim=start={MQ_RECORD_START}:duration={RECORD_LEN},setpts=PTS-STARTPTS[r_ui]",
        f"[1:v]{PERSON},trim=start={SPEAK_IN}:duration={RECORD_LEN},setpts=PTS-STARTPTS[r_person]",
        "[r_ui][r_person]blend=all_mode=lighten:shortest=1[record]",
        # 4. 無音の一拍
        f"color=c=black:s=1080x1920:r=30:d={BEAT_LEN}[beat]",
        # 5. カレンダー
        f"[3:v]{FULLBLEED},trim=start={CAL_GRID_SHOWN}:duration={CAL_LEN},setpts=PTS-STARTPTS[calendar]",
        # 6. ブランドカード
        f"color=c=black:s=1080x1920:r=30:d={BRAND_LEN},"
        f"drawtext=fontfile='{FONT}':textfile='{brand}':fontsize=84:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-70,"
        f"drawtext=fontfile='{FONT}':textfile='{tagline}':fontsize=40:fontcolor=white@0.8:x=(w-text_w)/2:y=(h-text_h)/2+50[brand]",
        "[wake][question][record][beat][calendar][brand]concat=n=6:v=1:a=0[body]",
        # 固定テロップ (全編) と答えの字幕 (発話中)
        f"[body]{drawtext(caption, 52, '160')},"
        f"{drawtext(answer, 46, '1320', f'between(t,{T_ANSWER_SUB_START},{T_ANSWER_SUB_END})', 0.45)},format=yuv420p[v]",
        # 音: アラーム (0〜録画停止。声の下で小さく)、目覚めの環境音、答えの声、締めの一音
        f"[4:a]atrim=0:{T_BEAT},asetpts=PTS-STARTPTS,aformat=sample_rates=48000:channel_layouts=stereo,"
        f"afade=t=in:st=0:d=0.3,"
        f"volume='if(lt(t,{T_RECORD}),0.9,if(lt(t,{T_RECORD + 2}),0.9-0.6*(t-{T_RECORD})/2,0.3))':eval=frame[alarm]",
        f"[0:a]atrim=start={wake_in}:duration={WAKE_LEN},asetpts=PTS-STARTPTS,aformat=sample_rates=48000:channel_layouts=stereo,volume=0.5[wake_a]",
        f"[1:a]atrim=start={SPEAK_IN}:duration={RECORD_LEN},asetpts=PTS-STARTPTS,aformat=sample_rates=48000:channel_layouts=stereo,"
        f"adelay={int(T_RECORD * 1000)}|{int(T_RECORD * 1000)}[speak_a]",
        f"[5:a]atrim=0:{CAL_LEN},asetpts=PTS-STARTPTS,aformat=sample_rates=48000:channel_layouts=stereo,volume=0.45,"
        f"afade=t=out:st={CAL_LEN - 1.0}:d=1.0,adelay={int(T_CAL * 1000)}|{int(T_CAL * 1000)}[chime_a]",
        "[alarm][wake_a][speak_a][chime_a]amix=inputs=4:duration=longest:normalize=0,alimiter=limit=0.95[a]",
    ]
    cmd = [
        "ffmpeg", "-nostdin", "-y", "-v", "error",
        "-i", str(wake), "-i", str(speak), "-i", str(mq), "-i", str(cal),
        "-stream_loop", "-1", "-i", str(alarm), "-i", str(chime),
        "-filter_complex", ";".join(filters),
        "-map", "[v]", "-map", "[a]", "-t", f"{TOTAL}",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-preset", "medium", "-crf", "18",
        "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-movflags", "+faststart",
        str(out),
    ]
    subprocess.run(cmd, check=True)
    sheet = out.with_suffix(".png")
    subprocess.run([
        "ffmpeg", "-nostdin", "-y", "-v", "error", "-i", str(out),
        "-vf", "fps=1,scale=240:-1,tile=6x3", "-frames:v", "1", str(sheet),
    ], check=True)
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--variant")
    parser.add_argument("--lang", choices=["en", "ja"])
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        for variant in CONFIG["variants"]:
            if args.variant and variant["id"] != args.variant:
                continue
            for lang in ("en", "ja"):
                if args.lang and lang != args.lang:
                    continue
                out = build(variant, lang, workdir)
                print(f"OUTPUT={out}")


if __name__ == "__main__":
    main()
