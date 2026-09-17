#!/usr/bin/env python3
"""縦動画 (shorts) 用に、架空人物の静止画から Veo で演技クリップを生成する (issue #167)。

使い方:
  <gemini-image-generator の venv の python3> demo-video/scripts/generate-shorts-motion.py --person worker --kind wake
  --kind は config.shorts.json の motion.clips のキー (wake = アラームで目を覚ます 8 秒、speak = 問いに答える 8 秒)

出力: demo-video/output/shorts/motion/<kind>-<person>.mp4 (音声付き 1080x1920)
冪等: 同じ入力 (静止画・プロンプト・パラメータ・モデル) の指紋で出力名を決め、存在すれば再生成しない。
      生成中に中断しても operation.json から再開する (Veo は非同期で 1〜3 分かかる)。
生成 AI は同じ入力でも画素一致しないため、出力は gitignore のまま (README のアセット節に出典を書く)。
"""

import argparse
import hashlib
import json
import os
import shutil
import time
from pathlib import Path

from google import genai
from google.genai import types


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--person", required=True)
    parser.add_argument("--kind", required=True, choices=["wake", "speak"])
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    config = json.loads((root / "config.shorts.json").read_text())
    person = config["people"][args.person]
    clip = config["motion"]["clips"][args.kind]
    prompt = clip["prompt"]
    if args.kind == "speak":
        prompt += f"\n{person['speak_extra']} Exact dialogue: {person['speak_dialogue']}"
    image = root / person["portrait"]
    parameters = config["motion"]["parameters"]
    model = config["motion"]["model"]

    out_dir = root / "output/shorts/motion"
    out_dir.mkdir(parents=True, exist_ok=True)
    fingerprint = hashlib.sha256(
        image.read_bytes() + prompt.encode() + json.dumps(parameters, sort_keys=True).encode() + model.encode()
        + clip.get("mode", "first-frame").encode()
    ).hexdigest()[:12]
    cached = out_dir / f"{args.kind}-{args.person}-{fingerprint}.mp4"
    final = out_dir / f"{args.kind}-{args.person}.mp4"
    if cached.exists():
        shutil.copyfile(cached, final)
        print(f"REUSED={cached}")
        print(f"OUTPUT={final}")
        return

    client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
    operation_file = cached.with_suffix(".operation.json")
    if operation_file.exists():
        operation = types.GenerateVideosOperation.model_validate_json(operation_file.read_text())
    else:
        # mode "reference": 静止画を最初のフレームに固定せず、人物の参照画像として渡す (布団に潜った状態から
        # 始めるなど、最初のフレームに顔が無い構図を作るため)。既定 (image-to-video) は静止画が最初のフレームになる
        if clip.get("mode") == "reference":
            source = types.GenerateVideosSource(prompt=prompt)
            config = types.GenerateVideosConfig(
                **parameters,
                reference_images=[
                    types.VideoGenerationReferenceImage(
                        image=types.Image.from_file(location=str(image)), reference_type="asset"
                    )
                ],
            )
        else:
            source = types.GenerateVideosSource(prompt=prompt, image=types.Image.from_file(location=str(image)))
            config = types.GenerateVideosConfig(**parameters)
        operation = client.models.generate_videos(model=model, source=source, config=config)
        operation_file.write_text(operation.model_dump_json(exclude_none=True))
        print(f"STARTED={args.kind}-{args.person}", flush=True)
    for attempt in range(90):
        if operation.done:
            break
        time.sleep(10)
        operation = client.operations.get(operation)
        operation_file.write_text(operation.model_dump_json(exclude_none=True))
        print(f"WAIT={args.kind}-{args.person} poll={attempt + 1}", flush=True)
    if not operation.done:
        raise TimeoutError("生成が続いている。同じコマンドで再開できる")
    if operation.error or not operation.response or not operation.response.generated_videos:
        raise RuntimeError(f"生成失敗: {operation.error or operation.response}")
    download = cached.with_suffix(".download")
    client.files.download(file=operation.response.generated_videos[0].video, destination=str(download))
    download.replace(cached)
    shutil.copyfile(cached, final)
    print(f"GENERATED={cached}")
    print(f"OUTPUT={final}")
    print(f"SHA256={hashlib.sha256(cached.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    main()
