---
feature: _root
verification: mobile-mcp
last_verified_commit: null
last_verified_at: null
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
- 無限追撃アラーム (スヌーズ) の検証は開発者メニューの「無限アラーム (issue #97)」セクションで行う: プレミアムを強制 ON →「アラーム設定を ON + スヌーズ無制限にする」→「テストアラームを 1 分後に登録」→ アプリを離れて発火を待つ。前提の不足は「検証を妨げる状態」行に表示される。**シミュレータでは停止操作の StopAlarmIntent.perform() が実行されないため、発火までは確認できるが停止後の追撃ループは確認できない (.claude/rules/ios-alarmkit-constraints.md の検証結果参照。実機検証は issue #2)**

## 実行ナレッジ

### SwiftUI の Toggle は WDA の要素 click では切り替わらない

- 発見日: 2026-08-17。開発者メニューの「Force premium (override)」を `tap-id` (要素 click) しても value が 0 のまま変わらなかった
- 対処: スイッチ部分の座標タップで切り替える (要素の rect 右端付近を狙う)

### リモート simulator (simtunnel) では通知バナーの発火確認ができない

- 発見日: 2026-08-17。夜リマインドの 1 分後発火を待って撮影しても、バナーが出なかったのか消えた後なのかを 1 フレームでは判別できない。WDA のスワイプでは通知センターも開けなかった
- 対処: 通知タップを伴う項目 (夜リマインド等) はローカル simulator で確認する (通知検証の手順は verify-ui-mobile-mcp skill の「通知タップの検証」参照)

## 横断確認項目

## 1. 起動と基本導線

- [x] **起動でホーム表示**: オンボーディング完了済みの状態で起動すると、ホーム (NEXT MORNING の大時刻・粒ストリップ・Journal / Life Calendar / Settings リンク) が表示される
  - 自動化: manual（起動直後の画面の目視確認）
- [x] **開発者メニューへの到達**: DEBUG ビルドでホーム左上のハンマーアイコン (debug_menu_link) から開発者メニューが開く
  - 自動化: manual（DEBUG 限定 UI の確認）
- [ ] **アラームの一連**: アラーム設定 → 1〜2 分後に発火 → 朝の問い → 回答 → 以降鳴らない、のコアループが通る (詳細は AlarmSetting / MorningQuestion の QA.md)
  - 自動化: manual（発火待ちを含む通し確認）

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

（未実行）

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
