---
feature: _root
verification: mobile-mcp
last_verified_commit: 25e17c225a4716fab8723809a68a9c1cf405fa8e
last_verified_at: 2026-08-22
---

# QA 全体ガイド

## 対象環境

- ローカルの iOS Simulator (iOS 26+)。バックエンドなし・データはローカルの SwiftData のみ (documents/PROJECT.md)
- 課金は RevenueCat。Debug ビルドは Test Store キーが既定 (Config.xcconfig) のため、課金フロー (価格表示・購入・復元) は simulator (simtunnel 含む) でそのまま検証できる (AGENTS.md「検証方法」)。実ストア相当 (StoreKit) の確認だけ Sandbox / StoreKit Configuration で行い、課金状態の作り込みは開発者メニューの「プレミアムを強制 (上書き)」を第一候補にする (.claude/rules/debug-menu-for-verification.md)

## 起動方法

- ユニットテスト・シミュレータビルド: xcodebuild (ログは ./tmp/build.log に保存し、全文を warning / error で検査する。CLAUDE.md「検証方法」)
- 動作確認は `/ios-simulator` skill を起点にする。本リポジトリは public のため simtunnel (リモート iOS Simulator。caller workflow: .github/workflows/simulator-session.yml) を優先し、Maestro / XCUITest / `xcrun simctl` が必要な時だけローカル sim-boot (`/sim-manager`) に倒す

## ログイン方法

ログイン機能なし (アカウント不要・データはローカルのみ)。

## 動作確認手段

- `/ios-simulator` (エントリ。simtunnel / ローカルの使い分けは同 skill Phase 1)
- `/verify-ui-mobile-mcp` (UI のインタラクティブ検証)
- `/sim-manager` (ローカルシミュレータ管理)
- 課金フローは Debug ビルドの既定 (Test Store キー) でそのまま検証できる。購入は SDK の「Test Store Purchase」モーダルで成功・失敗・キャンセルを選ぶ (検証手順の詳細は AGENTS.md「検証方法」)
- `/ios-storekit-testing` (実ストア相当の Sandbox / StoreKit Configuration 検証)
- 到達困難な状態の作り込みは、ホーム左上の開発者メニュー (debug_menu_link → DebugMenuPage、DEBUG ビルド限定) を使う (.claude/rules/debug-menu-for-verification.md)

### 再現が難しい操作の手順

- アラーム発火の確認は「1〜2 分後のアラーム」を設定して待つ。発火判定は画面表示で行う (シミュレータは sound .default だと鳴らない。CLAUDE.md「検証方法」)
- 朝の問いの提示状態は、開発者メニューの「Record alarm fired now」で発火記録を作って再現できる (解除は「Clear alarm fired record」)
- 回答データの投入は「Seed sample answers (10 days)」「Seed today's answer」「Seed yesterday's answer」、削除は「Delete all answers」。**Seed sample answers は回答が 1 件でもあると何もしない (SampleAnswerSeeder.swift の冪等仕様) ため、既に回答がある場合は「Delete all answers」→「Seed sample answers」の順で実行する**
- オンボーディングの再表示は「Reset onboarding」(回答・アラーム設定は消えない)
- 新規インストール状態は `xcrun simctl uninstall <UDID> com.bannzai.MementoMorning` → `xcrun simctl privacy <UDID> reset all com.bannzai.MementoMorning` → `xcrun simctl install <UDID> <.app のパス>` で作る (privacy reset で許可ダイアログも初回状態に戻る)
- アラーム (AlarmKit) の許可を後から変えるには、設定アプリ →「アプリ」→「MementoMorning」の「アラーム」トグルを操作する。アプリ内の「設定を開く」(`UIApplication.openSettingsURLString`) はシミュレータでは設定アプリのルートに着くため、そこから自分でたどる
- 無限追撃アラーム (スヌーズ) の検証は開発者メニューの「無限アラーム (issue #97)」セクションで行う: プレミアムを強制 ON →「アラーム設定を ON + スヌーズ無制限にする」→「テストアラームを 1 分後に登録」→ アプリを離れて発火を待つ。前提の不足は「検証を妨げる状態」行に表示される。**シミュレータでは停止操作の StopAlarmIntent.perform() が実行されないため、発火までは確認できるが停止後の追撃ループは確認できない (.claude/rules/ios-alarmkit-constraints.md の検証結果参照。実機検証は issue #2)**

## 実行ナレッジ

### SwiftUI の Toggle は WDA の要素 click では切り替わらない

- 発見日: 2026-08-17。開発者メニューの「Force premium (override)」を `tap-id` (要素 click) しても value が 0 のまま変わらなかった
- 対処: スイッチ部分の座標タップで切り替える (要素の rect 右端付近を狙う)

### AlarmKit のアラート内容はスクリーンショットに写らない

- 発見日: 2026-08-22。発火したアラームのアラートは、mobile-mcp でも `xcrun simctl io screenshot` でも黒い角丸としてしか写らない (アプリ名・問いの本文が写らず、停止ボタンの ✕ だけが写る)。システム側の別レイヤーで描画されるため
- 対処: 発火の判定はアクセシビリティツリー (`mobile_list_elements_on_screen`) で行う。アプリ名・問いの本文・停止ボタン (`identifier: xmark`) が並んでいれば発火している

### 通知バナーもスクリーンショットに写らない (ローカル simulator でも)

- 発見日: 2026-08-22。iPhone / iOS 26.5 のローカル simulator で、夜リマインドの発火時刻をまたいで 60 枚連写しても、バナーが写ったフレームは 1 枚も無かった (`xcrun simctl io screenshot`・mobile-mcp のどちらでも同じ。アクセシビリティツリーにも現れない)。AlarmKit のアラートと同じくシステムの別レイヤーで描画されるため。通知自体は配信されている
- 通知の**本文を読む**: 通知センター (ホーム画面で画面上部の端から下スワイプ) を開くと配信済み通知が写る。ここでタイトル・本文・「今」などの相対時刻を目視できる
- 通知を**タップして開く**: アプリをフォアグラウンドにしたまま `xcrun simctl push` し、直後に座標 (196, 95) (393×852pt 換算のバナー中央) を **1 回だけ** blind tap する。通知センター上の通知セルのタップは WDA でも Maestro でも反応しない。連打すると開いた sheet の外側を続けて叩いて即座に閉じてしまう (詳細は NightReflection の QA.md「再現手順」)

### ローカル simulator でもカメラの許可ダイアログは出る

- 発見日: 2026-08-22。iPhone / iOS 26.5 のローカル simulator で、朝の問いを開いた時にカメラの許可ダイアログが出た (MorningQuestion の QA.md に「ローカル simulator では許可ダイアログ自体が出ない」と書かれていたが、新規インストール + `simctl privacy reset` 済みの状態では出る)
- 「許可しない」を選ぶとテキスト入力へフォールバックする。テキスト回答で検証を進めたい時はこの経路が速い

### ボタンの無効状態は Maestro の enabled: false で判定する

- 発見日: 2026-08-22。mobile-mcp の `mobile_list_elements_on_screen` は要素の活性状態を返さない。本アプリの主要ボタンは無効でも見た目が有効時と同じ (白い塗りのまま dim しない) ため、スクリーンショットでも判定できない
- 対処: `maestro --udid <UDID> test` で `assertVisible: {id: <identifier>, enabled: false}` を実行する。通れば exit 0、活性なら exit 1 になる。**無効を確認したい状態と、活性であるはずの状態の両方で同じ assert を流し、後者が exit 1 で落ちることまで確認する** (落ちないなら selector 側の問題で、assert が無条件に通っている)

### テキストフィールドの全消去は Maestro の eraseText で行う

- 発見日: 2026-08-22。mobile-mcp の `mobile_type_keys` に `\b` を渡すと、バックスペースではなく `\b` という文字列がそのまま入力される
- 対処: Maestro の `tapOn: {id: <identifier>}` → `eraseText: 60` を使う。`eraseText` はカーソルより前しか消さず、`tapOn` はタップ位置にカーソルを置くため、1 回では消し残ることがある。同じ flow を 2〜3 回繰り返して、要素の value が消えたことを確認してから次へ進む

### リモート simulator (simtunnel) では通知バナーの発火確認ができない

- 発見日: 2026-08-17。夜リマインドの 1 分後発火を待って撮影しても、バナーが出なかったのか消えた後なのかを 1 フレームでは判別できない。WDA のスワイプでは通知センターも開けなかった
- 対処: 通知タップを伴う項目 (夜リマインド等) はローカル simulator で確認する (通知検証の手順は verify-ui-mobile-mcp skill の「通知タップの検証」参照)

## 横断確認項目

## 1. 起動と基本導線

- [x] **起動でホーム表示**: オンボーディング完了済みの状態で起動すると、ホーム (NEXT MORNING の大時刻・粒ストリップ・Journal / Life Calendar / Settings リンク) が表示される
  - 自動化: manual（起動直後の画面の目視確認）
- [x] **開発者メニューへの到達**: DEBUG ビルドでホーム左上のハンマーアイコン (debug_menu_link) から開発者メニューが開く
  - 自動化: manual（DEBUG 限定 UI の確認）
- [x] **アラームの一連**: アラーム設定 → 1〜2 分後に発火 → 朝の問い → 回答 → 以降鳴らない、のコアループが通る (詳細は AlarmSetting / MorningQuestion の QA.md)
  - 自動化: manual（発火待ちを含む通し確認）
  - 確認範囲: シミュレータで「設定 → 発火 → 停止ボタン → 朝の問い → テキスト回答 → ホーム反映 + 次アラームが翌朝」まで確認した。**アラートの停止ボタンからアプリが前面化して朝の問いが開くところまではシミュレータでも動く** (`openAppWhenRun`)。一方、停止操作を起点に走る `StopAlarmIntent.perform()` の中身 (未回答時の追撃アラーム再登録) はシミュレータで実行されないため、追撃ループは実機 QA (issue #2) に残る
  - 気づいた不具合 (issue: 未起票): 回答成立でホームへ戻った直後、フッターの「答えた日数」が 0 日のまま更新されなかった。粒ストリップ・「今朝のことば」・次アラームは即時更新される。アプリを再起動すると 1 日になる。`ContentView.swift` の `answeredCount` が `.onAppear` でしか再計算されず、朝の問い (fullScreenCover) が閉じても onAppear が再発火しないため。2026-08-22 に ContentView.swift で全回答を `@Query` で保持して件数を導出する形 (レビュー対応で確定した実装) で修正済み (2026-08-22 に最終実装で再検証し、回答成立直後に 1日 へ即時更新されることを確認)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **起動でホーム表示**: オンボーディング完了済みの状態で起動すると、ホーム (NEXT MORNING の大時刻・粒ストリップ・Journal / Life Calendar / Settings リンク) が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/7f66d9aa-375b-456c-b7a2-bdade68758f7.jpg" width="320">

</details>

### **開発者メニューへの到達**: DEBUG ビルドでホーム左上のハンマーアイコン (debug_menu_link) から開発者メニューが開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/ad724a07-0133-42fe-9d7b-50cd6b1c5627.jpg" width="320">

(開発者メニューが開き、回答件数・デバッグ操作の各行が表示されている)

</details>

### **アラームの一連**: アラーム設定 → 1〜2 分後に発火 → 朝の問い → 回答 → 以降鳴らない、のコアループが通る (詳細は AlarmSetting / MorningQuestion の QA.md)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22** (iPhone / iOS 26.5 ローカル simulator、日本語ロケール、回答 0 件から開始)

1. 端末時刻 12:21 に 2 分後の 12:23 でアラームを保存し、12:23 に発火した (2026-08-22 に「1〜2 分後」の指定どおりの間隔で再検証したもの。発火のスクショと判定根拠は AlarmSetting の「アラーム発火」)

2. アラートの停止ボタン (✕) をタップするとアプリが前面化し、朝の問いが全画面で表示された (カメラの許可ダイアログ・「カメラを準備しています」・「テキストで答える」)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/f8520139-5750-4d32-bc29-5f8daa00bf22.png" width="320">

3. カメラを「許可しない」でテキスト入力にフォールバックし、本文を入力

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/e8b1dbd1-e5ff-4606-8849-f0564fe34236.png" width="320">

4. 「これで確定する」で全画面が閉じ、ホームの「今朝のことば」に反映。次のアラームは同じ 10:26 のまま「あと 23 時間 55 分」= 翌朝になっている (当日ぶんは計画から外れている)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/ae06f9df-c0c7-4982-9f31-8af38c084f5b.png" width="320">

5. アプリを再起動すると「答えた日数 1日」になる (直後は 0 日のまま。上記の「気づいた不具合」)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/cd6046a1-c786-4cd4-9a11-f35907a02d53.png" width="320">

**「答えた日数」の即時更新の再検証: 2026-08-22** (同じ simulator。`ContentView.swift` で全回答を `@Query` で保持して件数を導出する修正版アプリ (25e17c2))

手順: 開発者メニューで全回答を削除 → 「アラーム発火を今すぐ記録」→ ホームを表示した状態でアプリを background / foreground して朝の問いを**ホームの上に**提示させる (朝の問いを閉じた後にホームの onAppear が再発火しない、不具合の再現条件と同じ経路にするため) → テキストで回答して確定。

6. 回答成立で全画面が閉じた直後のホーム。再起動なしで「答えた日数 1日」になり、「今朝のことば」(Watch the sunrise with my family) と粒ストリップの当日の点も同時に反映されている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/ad37defe-2892-4ba8-803c-f7a8d281be07.png" width="320">

7. 逆方向の確認。開発者メニューで全回答を削除してホームへ戻ると「答えた日数 0日」に更新され、「今朝のことば」も消える

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/2b1777c6-5336-4e21-9406-4167daa98460.png" width="320">

**最終実装 (25e17c2) での再確認: 2026-08-22** (同じ simulator。レビュー対応で確定した「全回答を `@Query` で保持して件数を導出する」実装のビルド)

手順: 朝の問いにテキストで回答して確定 → ホームのフッターを確認 → 開発者メニューで全回答を削除 → ホームへ戻ってフッターを確認 → 「アラーム発火を今すぐ記録」で朝の問いを再提示させ、テキストで回答して確定 → ホームのフッターを確認。いずれもアプリの再起動を挟まない。

8. 回答成立でホームへ戻った直後。再起動なしで「答えた日数 1日」になっている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/3a285bbc-d3b7-4dca-a4b3-d983af811af6.png" width="320">

9. 開発者メニューで全回答を削除してホームへ戻ると「答えた日数 0日」に即時更新され、「今朝のことば」も消える

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/ff8514cb-9cf9-40ee-9fa8-1caef17d652b.png" width="320">

10. 0 件の状態から「アラーム発火を今すぐ記録」→ 朝の問いに回答すると、ホームのフッターが再起動なしで「答えた日数 1日」に戻る

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/f431d874-474b-4dc8-8652-7b9af4d8890b.png" width="320">

</details>

</details>

## 機能別 QA.md

- [MorningQuestion](MementoMorning/Features/MorningQuestion/QA.md) — コア体験 (朝の問い・動画回答・追撃アラーム)
- [AlarmSetting](MementoMorning/Features/AlarmSetting/QA.md) — アラーム設定と再スケジュール
- [Onboarding](MementoMorning/Features/Onboarding/QA.md) — 初回起動フロー
- [AnswerLog](MementoMorning/Features/AnswerLog/QA.md) — ジャーナル (無料枠の課金線を含む)
- [Paywall](MementoMorning/Features/Paywall/QA.md) — 課金 (購入・復元)
- [NightReflection](MementoMorning/Features/NightReflection/QA.md) — 夜リマインドと振り返り
- [AnswerEdit](MementoMorning/Features/AnswerEdit/QA.md) — 回答の編集
- [LifeCalendar](MementoMorning/Features/LifeCalendar/QA.md) — 人生カレンダー
- [SevenMornings](MementoMorning/Features/SevenMornings/QA.md) — 7 日の節目
- [ShareCard](MementoMorning/Features/ShareCard/QA.md) — 共有カード

## QA 対象外

- DebugMenu — `#if DEBUG` 限定の開発者メニュー (DebugMenuPage.swift)。リリースビルドに含まれず、QA で状態を作るための道具そのもののため対象外
- SnapshotUITest — `#if DEBUG` + 起動引数 isSnapshotUITest でのみ表示される多言語スクリーンショット撮影用画面 (MementoMorningApp.swift の分岐)。ユーザーは到達できないため対象外
- Question — QuestionPage は機能配線前のデザインシェル (録画ボタンは見た目のみ。QuestionPage.swift 冒頭コメント)。本番導線からは到達できず、開発者メニューの「Open QuestionPage (design shell)」からのみ開ける。本番のコア体験は MorningQuestion が担うため対象外
