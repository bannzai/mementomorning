# デモ動画の収録手順 (issue #94)

`demo-video-builder` skill (config: `config.json`) で Shipaton 提出用の 2 分デモ動画を収録・合成する。
手作業で設定済みの端末に依存せず、この手順だけで再収録できることを目的とする。

## 前提

- ローカルの iOS Simulator (Maestro / `xcrun simctl` が必要なため simtunnel ではなくローカル。CLAUDE.md「検証方法」)
- `brew install ffmpeg maestro jq`
- Debug ビルド (RevenueCat は Test Store キーが既定。Config.xcconfig)

## 収録環境の初期化

```sh
# 1. プロジェクト固有シミュレータを起動し UDID を控える
sim-boot   # 最終行の DEVICE_UDID= を使う
export DEVICE_UDID=<UDID>

# 2. アプリの表示言語を英語に固定する (収録 flow は英語のローカライズ済み文言で要素を特定するため必須。
#    日本語環境のままだと journal.yaml 等の英語文言待ちがタイムアウトする)
xcrun simctl spawn $DEVICE_UDID defaults write .GlobalPreferences AppleLanguages -array en-US
xcrun simctl spawn $DEVICE_UDID defaults write .GlobalPreferences AppleLocale -string en_US
xcrun simctl shutdown $DEVICE_UDID && xcrun simctl boot $DEVICE_UDID

# 3. ビルドとインストール
make build
xcrun simctl install $DEVICE_UDID tmp/DerivedData/Build/Products/Debug-iphonesimulator/MementoMorning.app

# 4. 初回起動前の状態作り込み (オンボーディングのスキップ・写真ライブラリ許可・ステータスバー 9:41)
xcrun simctl spawn $DEVICE_UDID defaults write com.bannzai.MementoMorning hasCompletedOnboarding -bool true
xcrun simctl privacy $DEVICE_UDID grant photos com.bannzai.MementoMorning
xcrun simctl status_bar $DEVICE_UDID override --time "9:41"
```

課金状態の前提: **未購入 (isPremium = false)** で収録する。Test Store で購入済みのシミュレータや
「プレミアムを強制 (上書き)」トグルが ON のままだと、ジャーナルのロック行 (`journal_paywall_link`) が
生成されず `paywall.yaml` が失敗する。購入済みならアプリを uninstall して入れ直し、
開発者メニューでプレミアム強制トグルが OFF であることを確認してから収録する。

## 収録と合成

```sh
SKILL=~/.claude/skills/demo-video-builder/scripts

# 共通の初期状態 (サンプル回答 10 件・アラーム 7:00・AlarmKit 許可)
maestro --device $DEVICE_UDID test demo-video/flows/prep/setup.yaml

# シーン録画 (prep が必要なシーンは直前に実行する)
bash $SKILL/record-scene.sh demo-video/config.json journal
bash $SKILL/record-scene.sh demo-video/config.json seven-mornings
bash $SKILL/record-scene.sh demo-video/config.json paywall
bash $SKILL/record-scene.sh demo-video/config.json life-calendar

maestro --device $DEVICE_UDID test demo-video/flows/prep/night.yaml
bash $SKILL/record-scene.sh demo-video/config.json night-banner   # バナー到着 (登録の約 60 秒後) まで映し続ける
bash $SKILL/record-scene.sh demo-video/config.json night-reflection

maestro --device $DEVICE_UDID test demo-video/flows/prep/morning-question.yaml
bash $SKILL/record-scene.sh demo-video/config.json morning-question

maestro --device $DEVICE_UDID test demo-video/flows/prep/alarm.yaml
bash $SKILL/record-scene.sh demo-video/config.json alarm

# 合成と機械検証
bash $SKILL/compose-video.sh demo-video/config.json
bash $SKILL/verify-output.sh demo-video/config.json
```

出力: `demo-video/output/memento-morning-demo.mp4` (gitignore 対象。動画バイナリはコミットしない)

## 注意 (シミュレータで撮れないもの)

- AlarmKit の発火 UI はシミュレータでは中身が描画されない (空の黒ピルになることを実測)。
  発火 UI の実映像・実カメラのプレビュー・文字起こしの反映は実機収録カット (PR #95 の一覧参照)
- 夜リマインドのバナーはシステム UI のため Maestro の要素検出に乗らない。`night-banner.yaml` は
  アサートせず固定時間ホームを映して到着を録画に収め、到着はフレーム抽出で確認する
- `xcrun simctl status_bar` の `--time` は HH:mm 形式 (ISO 日時文字列は Invalid argument で失敗する)
