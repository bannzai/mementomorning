---
feature: _root
verification: mobile-mcp
last_verified_commit: 75b0bf87eb1e52b1737ef435c61b32f36467f8b9
last_verified_at: 2026-08-26
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

- [x] **起動でホーム表示**: オンボーディング完了済みの状態で起動すると、ホーム (NEXT MORNING の大時刻・背景に積もる答えた朝の粒・Journal / Calendar / Settings リンク) が表示される。背景の粒 (温白 9%) の上でも操作系の文字が読める (issue #117 で直近 14 日の粒ストリップを背景の積み上げに置き換え。issue #137 で Dots リンクと点画面を削除)
  - 自動化: manual（起動直後の画面の目視確認）
- [x] **開発者メニューへの到達**: DEBUG ビルドでホーム左上のハンマーアイコン (debug_menu_link) から開発者メニューが開く
  - 自動化: manual（DEBUG 限定 UI の確認）
- [x] **アラームの一連**: アラーム設定 → 1〜2 分後に発火 → 朝の問い → 回答 → 以降鳴らない、のコアループが通る (詳細は AlarmSetting / MorningQuestion の QA.md)
  - 自動化: manual（発火待ちを含む通し確認）
  - 確認範囲: シミュレータで「設定 → 発火 → 停止ボタン → 朝の問い → テキスト回答 → ホーム反映 + 次アラームが翌朝 → 以降鳴らない」まで、1 本の 2 分後アラームで通しで確認した。ただし**停止ボタンのタップでは `StopAlarmIntent.perform()` が実行されず、`openAppWhenRun` によるアプリの前面化も起きない** (`.claude/rules/ios-alarmkit-constraints.md` に記録済みのシミュレータ制約)。朝の問いは手動で前面化した時に `Rescheduler` が発火を検知して提示する経路で確認しており、停止操作を起点にした追撃アラームの再登録 (未回答時) は実機 QA (issue #2) に残る
  - 気づいた不具合 (issue: 未起票): 回答成立でホームへ戻った直後、フッターの「答えた日数」が 0 日のまま更新されなかった。粒ストリップ・「今朝のことば」・次アラームは即時更新される。アプリを再起動すると 1 日になる。`ContentView.swift` の `answeredCount` が `.onAppear` でしか再計算されず、朝の問い (fullScreenCover) が閉じても onAppear が再発火しないため。2026-08-22 に ContentView.swift で fetchCount + SwiftData の保存通知 (`ModelContext.didSave`) で再計算する形 (レビュー対応で確定した実装。全回答を @Query でホームに保持しない) で修正済み (最終実装での再検証はエビデンス末尾を参照)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **起動でホーム表示**: オンボーディング完了済みの状態で起動すると、ホーム (NEXT MORNING の大時刻・背景に積もる答えた朝の粒・Journal / Calendar / Settings リンク) が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-26 (2 回目)** (simtunnel、英語ロケール、サンプル回答 10 日分投入後。カレンダー復活 (75b0bf8) 後の確認)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260826/cdbae8a6-fba2-47a9-97d8-1a0528e76286.jpg" width="320" />

(フッターのリンクが Journal / Calendar / Settings の 3 つ。画面下端に温白 9% の粒が 10 個積もり、大時刻・今朝のことば・「10 mornings answered」はすべて可読。Calendar リンクからカレンダー画面が開くことも同時に確認 — 記録は LifeCalendar/QA.md)

**確認日: 2026-08-26 (1 回目)** (simtunnel、英語ロケール、サンプル回答 10 日分投入後。Dots / Calendar リンクと両画面を削除した時点の確認。その後カレンダーは復活)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260826/13099096-5756-402d-8aff-e297e379c5fc.jpg" width="320" />

(フッターのリンクが Journal / Settings の 2 つになり、画面下端に温白 9% の粒が 10 個積もっている。大時刻・今朝のことば・「10 mornings answered」はすべて可読。Journal リンクからジャーナルが開くことも同時に確認)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260826/6a58ab21-4306-4664-a979-477058b46f5b.jpg" width="320" />

**確認日: 2026-08-23** (simtunnel、英語ロケール、サンプル回答 10 日分投入後。issue #117 の再設計後の確認)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260823/3ceb8f70-bd04-4819-9935-124a4ff9bd02.jpg" width="320" />

(画面下端に温白 9% の粒が 10 個積もり、大時刻・今朝のことば・「10 mornings answered」・Journal / Dots / Calendar / Settings リンクはすべて可読)

**確認日: 2026-08-17** (旧レイアウト: 粒ストリップ + Journal / Life Calendar / Settings)
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

**確認日: 2026-08-22** (iPhone / iOS 26.5 ローカル simulator、日本語ロケール)

開発者メニューで「全回答を削除」+「アラーム発火記録を削除」を実行し、回答 0 件・発火記録なしの状態から、**1 本の 2 分後アラーム (設定 12:43 / 実発火 12:43:00) だけ**を使って通しで実行した記録。

1. 端末時刻 12:41 に 2 分後の 12:43 でアラームを保存した。保存直後のホームに、大時刻 12:43・「あと 0 時間 2 分」・「答えた日数 0日」が同じ画面で出ている (「今朝のことば」はまだ無い)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/7a14c000-3614-46ee-85de-d4adb14380f4.png" width="320">

2. アプリをバックグラウンド (iOS ホーム画面) にして待機し、12:43:00 に画面上部へアラートが出た。スクショには黒い角丸と右の ✕ しか写らないため、発火の判定はアクセシビリティツリーで行った (アプリ名 `MementoMorning`・問いの本文「今日死ぬとしたら何をやりたいですか？」・停止ボタン `identifier: xmark`)。simulator の unified log でも同時刻に AlarmKitCore が `Scheduled alarm is due to begin` を出している

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/aabdd484-f688-459e-b720-879f7043ac28.png" width="320">

3. アラートの停止ボタン (✕) をタップするとアラートは消えたが、**アプリは前面化しなかった** (下の「停止操作と追撃ループの扱い」を参照)。手動でアプリを前面化すると、朝の問いが全画面 (fullScreenCover) で表示された。カメラは以前の検証で拒否済みのため許可ダイアログは出ず、「カメラを使えないため、テキストで答えます」のテキスト入力へフォールバックしている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/67eab817-f80d-4ccb-a5c6-be7aa5810d9e.png" width="320">

4. テキストで「Watch the sunrise from the hill」を入力して「これで確定する」を押すと全画面が閉じ、ホームへ戻った。**アプリの再起動を挟まずに**、「今朝のことば」への反映・「答えた日数 1日」・次のアラームが翌朝 (12:43 / 「あと 23 時間 56 分」) の 3 点が同じ画面で揃っている。粒ストリップの当日の点も同時に埋まっている。「答えた日数」の即時更新は、レビュー対応で確定した最終実装 (`ContentView.swift` で `fetchCount` + SwiftData の保存通知 `ModelContext.didSave` で再計算する形) での確認

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/ed614c7c-58fd-4330-a371-91bb227f170d.png" width="320">

5. そのままアプリをバックグラウンドにして、発火時刻を過ぎた 12:48 / 12:51 / 12:54 の各時点でアクセシビリティツリーを確認し、アラートが再度出ていないことを確認した (アプリ名・問いの本文・停止ボタンのいずれも無い)。バックアップアラームの発火枠 (`backupAlarmCount` 2 本 × `backupAlarmIntervalMinutes` 5 分 = 12:48 / 12:53) を通過済みで、unified log の mobiletimerd にも 12:43:35〜12:55:00 の間に発火のイベント (`Firing event` / `due to begin` / `alerting`) は出ていない

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/c9cecfd7-886f-4d6a-aaf5-6e8fae327ddb.png" width="320">

**停止操作と追撃ループの扱い**

今回の通しでは、停止ボタンのタップで `StopAlarmIntent.perform()` が実行されず、`openAppWhenRun` によるアプリの前面化も起きなかった。判定の根拠は次の 3 点:

- `perform()` の 1 行目で書き込む `stopIntentSpikeLog` キーが UserDefaults に作られていない
- unified log の subsystem `com.bannzai.MementoMorning` に `StopIntentSpike` のエントリが無い
- 停止直後 (12:43:31) の SpringBoard のログが `Application process state changed for com.bannzai.MementoMorning: taskState: Suspended; visibility: Background` のままで、前面化していない

手順 3 で朝の問いが表示されたのは停止操作の効果ではなく、手動で前面化した時に `Rescheduler` が「発火予定日時を過ぎた main アラームの記録」を検知して発火を記録する経路による (発火記録 `lastAlarmFiredDate` も停止時刻ではなく main の発火予定日時 12:43:00 で入っていた)。

これは `.claude/rules/ios-alarmkit-constraints.md` に記録済みのシミュレータ制約 (issue #3 / issue #97 で再現。`Could not find an intent with identifier StopAlarmIntent` で `perform()` が未実行になる) と一致する。したがって **停止操作を起点にした追撃アラームの再登録 (「答えるまで止まらない」の中核) はシミュレータでは確認できず、実機 QA (issue #2) に残る**。

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
- [LifeCalendar](MementoMorning/Features/LifeCalendar/QA.md) — カレンダー
- [SevenMornings](MementoMorning/Features/SevenMornings/QA.md) — 7 日の節目
- [ShareCard](MementoMorning/Features/ShareCard/QA.md) — 共有カード

## QA 対象外

- DebugMenu — `#if DEBUG` 限定の開発者メニュー (DebugMenuPage.swift)。リリースビルドに含まれず、QA で状態を作るための道具そのもののため対象外
- SnapshotUITest — `#if DEBUG` + 起動引数 isSnapshotUITest でのみ表示される多言語スクリーンショット撮影用画面 (MementoMorningApp.swift の分岐)。ユーザーは到達できないため対象外
- Question — QuestionPage は機能配線前のデザインシェル (録画ボタンは見た目のみ。QuestionPage.swift 冒頭コメント)。本番導線からは到達できず、開発者メニューの「Open QuestionPage (design shell)」からのみ開ける。本番のコア体験は MorningQuestion が担うため対象外
