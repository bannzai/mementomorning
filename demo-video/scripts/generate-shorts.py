#!/usr/bin/env python3
"""公開済みデモと架空人物から英日6本の短尺動画を冪等に生成・検査する。"""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from PIL import Image, ImageDraw, ImageFont


def run(arguments):
    """外部コマンドの失敗を隠さず、呼び出し元へ伝える。"""
    subprocess.run(arguments, check=True)


def ffmpeg(arguments):
    """並行作業の端末負荷を抑えて動画を処理する。"""
    run(["ffmpeg", "-nostdin", "-y", "-v", "warning", "-threads", "2",
         "-filter_threads", "2", "-filter_complex_threads", "2", *arguments])


def download_source(source, config):
    """公開素材をcurlで取得し、照合できたファイルだけをキャッシュする。"""
    if not source.exists():
        # 公開R2がurllibのリクエストに403を返すため、既存の収録手順と同じcurlを使う。
        run(["curl", "-fLsS", "--retry", "2", config["url"], "-o", str(source.with_suffix(".download"))])
        if hashlib.sha256(source.with_suffix(".download").read_bytes()).hexdigest() != config["sha256"]:
            raise ValueError("取得した原動画のSHA-256が一致しません")
        source.with_suffix(".download").replace(source)
    if hashlib.sha256(source.read_bytes()).hexdigest() != config["sha256"]:
        raise ValueError("原動画のSHA-256が一致しません。別版を黙って使用しません")


def encode(output):
    """投稿先で再生しやすい H.264 と正方形ピクセルの出力条件を返す。"""
    return ["-c:v", "libx264", "-threads", "2", "-preset", "fast", "-crf", "20",
            "-pix_fmt", "yuv420p", "-color_range", "tv", "-colorspace", "bt709",
            "-color_primaries", "bt709", "-color_trc", "bt709", "-r", "30", "-an", str(output)]


def text(image, content, y, size, language, color):
    """右側の操作ボタンを避けた領域へ、改行を保って文字を描く。"""
    font = ImageFont.truetype(
        "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc" if language == "ja"
        else "/System/Library/Fonts/Supplemental/Arial Bold.ttf", size)
    draw = ImageDraw.Draw(image)
    for index, line in enumerate(content.splitlines()):
        bounds = draw.textbbox((0, 0), line, font=font)
        if bounds[2] - bounds[0] > 840:
            raise ValueError(f"セーフエリア幅を超える文言: {line}")
        # 画面中心ではなく、右12%を除いた領域の中心へ配置する。
        draw.text((500, y + index * (size + 14)), line, font=font,
                  fill=color, anchor="mt", stroke_width=1)


def card(path, lines, language):
    """映像内の編集カードを描く。アプリの画面収録と混同する枠は付けない。"""
    image = Image.new("RGB", (1080, 1920), "#101114")
    for content, y, size, color in lines:
        text(image, content, y, size, language, color)
    image.save(path)


def still_clip(image, duration, output, zoom):
    """静止画に穏やかな寄りを加えるか、編集カードとして表示する。"""
    filters = "scale=1080:1920:force_original_aspect_ratio=increase:out_range=tv,crop=1080:1920,setsar=1"
    if zoom:
        # 2秒で約2%だけ寄せ、寝起きの静けさを保つ。
        filters += ",zoompan=z='1+on*0.00035':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=1:s=1080x1920:fps=30"
    # PNGのICCと収録映像の色属性の差で、連結後のフィルターを再初期化させない。
    filters += ",sidedata=delete,setparams=range=limited:color_primaries=bt709:color_trc=bt709:colorspace=bt709"
    ffmpeg(["-loop", "1", "-framerate", "30", "-i", str(image), "-t", str(duration),
            "-vf", filters, *encode(output)])


def source_clip(source, start, duration, output, crop):
    """CFR化した原動画の指定区間を、安全領域に収まる画面サイズにする。"""
    ffmpeg(["-reinit_filter", "0", "-i", str(source), "-vf",
            f"fps=30,trim=start={start}:duration={duration},setpts=PTS-STARTPTS,"
            f"{crop},scale=648:-2,setsar=1,pad=1080:1920:170:380:color=0x101114,"
            "tpad=stop_mode=clone:stop_duration=4.5,sidedata=delete,"
            "setparams=range=limited:color_primaries=bt709:color_trc=bt709:colorspace=bt709",
            "-t", "4.5" if output.stem == "answer" else str(duration), *encode(output)])


def soundtrack(source, root, variant, work):
    """回答音声をPCMに正規化してから、演出音とBGMを混ぜる。"""
    # 原動画の音声PTSを持ち越さず、サンプル数から連続した時刻を作る。
    ffmpeg(["-ss", str(variant["start"]), "-i", str(source), "-t", str(variant["duration"]),
            "-vn", "-af", "asetpts=N/SR/TB", "-ar", "48000", "-ac", "2",
            str(work / "voice.wav")])
    ffmpeg(["-i", str(work / "voice.wav"), "-i", str(root / "assets/bgm-mandolin.m4a"),
            "-f", "lavfi", "-i", "sine=frequency=880:sample_rate=48000:duration=16",
            "-filter_complex",
            f"[0:a]afade=t=in:d=0.03,afade=t=out:st={variant['duration'] - 0.08}:d=0.08,"
            "adelay=6000|6000[voice];"
            "[1:a]atrim=duration=16,asetpts=N/SR/TB,volume=0.08,afade=t=out:st=14:d=2[bgm];"
            "[2:a]volume='if(between(t,2,10.5)*lt(mod(t,1),0.13),0.12,0)':eval=frame[tone];"
            "[voice][bgm][tone]amix=inputs=3:normalize=0:duration=longest,asetpts=N/SR/TB[a]",
            "-map", "[a]", "-t", "16", "-ar", "48000", "-ac", "2", str(work / "soundtrack.wav")])


def verify(output, overlay, picture):
    """規格・全フレームの固定テロップ・音声を検査しコンタクトシートを作る。"""
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(output)]))
    video = next(stream for stream in probe["streams"] if stream["codec_type"] == "video")
    assert (video["width"], video["height"], video["r_frame_rate"]) == (1080, 1920, "30/1")
    assert abs(float(probe["format"]["duration"]) - 16) < 0.05
    audio = next(stream for stream in probe["streams"] if stream["codec_type"] == "audio")
    assert audio["codec_name"] == "aac" and int(audio["sample_rate"]) == 48000
    run(["ffmpeg", "-v", "error", "-xerror", "-threads", "2", "-i", str(output),
         "-map", "0", "-f", "null", "-"])
    # 不透明な固定見出しを480フレームすべてで照合し、途中消失も検出する。
    expected = Image.open(overlay).convert("RGB").crop((60, 240, 940, 490)).resize((88, 25))
    process = subprocess.Popen([
        "ffmpeg", "-v", "error", "-threads", "2", "-i", str(output), "-vf",
        "crop=880:250:60:240,scale=88:25", "-pix_fmt", "rgb24", "-f", "rawvideo", "-"],
        stdout=subprocess.PIPE)
    frame_count = 0
    while data := process.stdout.read(88 * 25 * 3):
        assert len(data) == 88 * 25 * 3
        if sum(abs(a - b) for a, b in zip(data, expected.tobytes())) / len(data) >= 12:
            process.terminate()
            process.wait()
            raise ValueError(f"固定テロップの不一致: {output.name} frame={frame_count}")
        frame_count += 1
    assert process.wait() == 0 and frame_count == 480
    # テロップ検査だけでは、背景が静止・遅延したままの合成を見逃すため。
    before = subprocess.check_output([
        "ffmpeg", "-v", "error", "-threads", "2", "-reinit_filter", "0", "-i", str(picture),
        "-vf", "crop=640:800:180:550,scale=64:80", "-pix_fmt", "rgb24", "-f", "rawvideo", "-"])
    after = subprocess.check_output([
        "ffmpeg", "-v", "error", "-threads", "2", "-i", str(output),
        "-vf", "crop=640:800:180:550,scale=64:80", "-pix_fmt", "rgb24", "-f", "rawvideo", "-"])
    assert len(before) == len(after) == 480 * 64 * 80 * 3
    for index in range(480):
        start = index * 64 * 80 * 3
        stop = start + 64 * 80 * 3
        if sum(abs(a - b) for a, b in zip(before[start:stop], after[start:stop])) / (stop - start) >= 8:
            raise ValueError(f"映像の時刻不一致: {output.name} frame={index}")
    ffmpeg(["-i", str(output), "-vf",
            "select='not(mod(n,30))',scale=270:480,tile=4x4", "-frames:v", "1",
            "-update", "1", str(output.with_suffix(".png"))])
    return {"file": output.name, "width": video["width"], "height": video["height"],
            "fps": video["r_frame_rate"], "duration": probe["format"]["duration"],
            "audio": audio["codec_name"], "headline_frames": frame_count}


def main():
    """固定済み素材を検証して再取得できる、短尺動画生成の入口。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, help="公開済み62秒版のローカルキャッシュ")
    arguments = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    config = json.loads((root / "config.shorts.json").read_text())
    output = root / "output/shorts"
    output.mkdir(parents=True, exist_ok=True)
    source = arguments.source or output / "source.mp4"
    if arguments.source and not source.exists():
        raise FileNotFoundError(source)
    download_source(source, config["source"])
    results = []
    for variant in config["variants"]:
        work = output / variant["id"]
        work.mkdir(exist_ok=True)
        still_clip(root / f"assets/person-{variant['person']}.png", 2, work / "wake.mp4", True)
        # 既存の字幕とステータスバーを除き、アラーム時刻・操作だけを残す。
        source_clip(source, 5, 2, work / "alarm.mp4", "crop=900:1300:90:120")
        source_clip(source, variant["start"], variant["duration"], work / "answer.mp4", "null")
        still_clip(root / f"assets/person-{variant['person']}.png", 1.5, work / "quiet.mp4", True)
        soundtrack(source, root, variant, work)
        for language in ("en", "ja"):
            card(work / "question.png", [
                ("If today were your last day\nwhat would you want to do?" if language == "en"
                 else "もし今日が最後の日なら\n何をしたいですか", 750, 48, "#f4f1ea")], language)
            still_clip(work / "question.png", 2, work / "question.mp4", False)
            card(work / "tonight.png", [
                ("TONIGHT" if language == "en" else "今夜", 660, 30, "#b9a88b"),
                ("Are you keeping it?" if language == "en" else "守れてますか?", 780, 56, "#f4f1ea"),
                (variant["answer"][language], 1000, 40, "#c4c5c8")], language)
            still_clip(work / "tonight.png", 3, work / "tonight.mp4", False)
            card(work / "brand.png", [("Memento Morning", 880, 64, "#f4f1ea")], "en")
            still_clip(work / "brand.png", 1, work / "brand.mp4", False)
            (work / "concat.txt").write_text("\n".join(
                f"file '{name}.mp4'" for name in ("wake", "alarm", "question", "answer", "quiet", "tonight", "brand")))
            ffmpeg(["-f", "concat", "-safe", "0", "-i", str(work / "concat.txt"),
                    "-c", "copy", str(work / "picture.mp4")])
            overlay = Image.new("RGBA", (1080, 1920))
            ImageDraw.Draw(overlay).rectangle((60, 240, 940, 490), fill="#101114")
            text(overlay, variant["headline"][language], 262, 54 if language == "en" else 48,
                 language, "#ffffff")
            # 無料プランでも鳴り続けると誤認させない、全編共通の条件表示。
            text(overlay, "Endless follow-up alarms require Premium" if language == "en"
                 else "繰り返し鳴るアラームはプレミアム機能", 1460, 28, language, "#e8e5df")
            overlay.save(work / "overlay.png")
            ffmpeg(["-reinit_filter", "0", "-i", str(work / "picture.mp4"), "-loop", "1", "-framerate", "30",
                    "-i", str(work / "overlay.png"), "-i", str(work / "soundtrack.wav"),
                    "-filter_complex", "[0:v][1:v]overlay=0:0:shortest=1,format=yuv420p[v]",
                    "-map", "[v]", "-map", "2:a", "-t", "16", "-c:v", "libx264",
                    "-threads", "2", "-preset", "fast", "-crf", "20", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-map_metadata", "-1",
                    str(output / f"{variant['id']}-{language}.mp4")])
            results.append(verify(output / f"{variant['id']}-{language}.mp4", work / "overlay.png", work / "picture.mp4"))
    (output / "verification.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
