---
feature: Onboarding
verification: mobile-mcp
last_verified_commit: 25e17c225a4716fab8723809a68a9c1cf405fa8e
last_verified_at: 2026-08-22
---

# Onboarding QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/11 (受け入れ条件)
- 関連: なし

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 新規インストール → 許可 → アラーム設定 → 翌朝の問い、の一連が通る | 3 ステップの通し / 完了でホームへ |
| S2 | 許可拒否時の導線 (設定アプリへの誘導) がある | 許可拒否時の設定誘導 |

## 1. ステップ進行

- [x] **初回表示**: 新規インストール状態 (開発者メニューの Reset onboarding で再現) で起動すると、コンセプト提示「死を想ってから、朝を始める。」が表示される
  - 自動化: manual（初回状態の作り込みと目視確認）
- [x] **3 ステップの通し**: 「はじめる」(onboarding_begin) → 許可ステップ (アラーム・通知の許可ダイアログ) → アラーム設定ステップ、の順にフェードで進む
  - 自動化: manual（OS 許可ダイアログの操作が必要）
  - 許可ダイアログの説明文: 英語ロケールで Info.plist に書いた用途説明文が表示される (issue #50 でキー名表示を解消済み)
- [x] **許可拒否時の設定誘導**: アラームまたは通知の許可を拒否すると、設定アプリへの誘導が表示される。設定アプリで許可して戻ると表示が追従する
  - 自動化: manual（画面上の導線の目視確認。誘導要否の判定ロジックは MementoMorningTests/OnboardingPermissionTests.swift がカバー済み）
  - 設定アプリで**アラーム**の許可を変える手順: `UIApplication.openSettingsURLString` での遷移はシミュレータでは設定アプリのルートに着くため、「アプリ」→「MementoMorning」まで自分でたどる。その画面の「アラーム」トグルが AlarmKit の許可で、ON にしてステータスバー左上の「◀ MementoMorning」でアプリへ戻ると、OnboardingPage の scenePhase 監視が許可状態を再取得して表示が追従する
- [x] **練習の録画にも上限とインジケーター**: 練習ステップの録画は朝の問いと同じ 10 秒の上限で自動停止し、録画中は同じ点 + タイマー「0:02 / 0:10」とリングで予告する (issue #71)。自動停止で練習完了「You're ready for the morning.」へ進む
  - 自動化: manual（開発者メニューの疑似録画モードで simulator から確認。共通 View は MementoMorning/Features/MorningQuestion/VideoAnswerRecordingControls.swift）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **初回表示**: 新規インストール状態 (開発者メニューの Reset onboarding で再現) で起動すると、コンセプト提示「死を想ってから、朝を始める。」が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/8022b8d1-4207-46af-9b4f-ff83f8ee209b.jpg" width="320">

(simtunnel の新規インストール状態で確認。英語ロケールのため文言は「Remember death. Then begin your morning.」)

</details>

### **3 ステップの通し**: 「はじめる」(onboarding_begin) → 許可ステップ (アラーム・通知の許可ダイアログ) → アラーム設定ステップ、の順にフェードで進む

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/206bbb45-34f7-4e39-9433-c43868898e7c.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/c0b00f70-4f6e-4ad4-a004-9bb068ffd42a.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/0e62fb8c-0220-4e6f-a9e5-544d0b081b32.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/ea2c0abc-6268-4a44-88da-3db2e7d16f6f.jpg" width="320">

(許可ステップ → アラーム許可ダイアログ → 通知許可ダイアログ (アラーム行が「Allowed」に変化) → アラーム設定ステップ 7:00 AM)

**再確認日: 2026-08-17 (issue #50 の修正後。英語ロケール・ローカル simulator の新規インストール)**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/19b1ed86-98b2-44bc-b448-556299eae470.png" width="320" />

(アラーム許可ダイアログの説明文がキー名ではなく「Used to ring the alarm at your set time and stop it by answering today's question.」になっている)

</details>

### **許可拒否時の設定誘導**: アラームまたは通知の許可を拒否すると、設定アプリへの誘導が表示される。設定アプリで許可して戻ると表示が追従する

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22** (ローカル simulator iPhone / iOS 26.5、日本語ロケール。`xcrun simctl uninstall` → `install` の新規インストール状態から実施)

1. アラームの許可ダイアログで「許可しない」、通知は「許可」を選んだ直後。「許可は設定アプリから変更できます」と「設定を開く」が現れ、アラーム行だけ「許可済み」が付いていない

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/b1d336d9-8965-405b-81f7-1a296895d7de.png" width="320">

2. 設定アプリ →「アプリ」→「MementoMorning」で「アラーム」トグルを ON にした状態

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/971263b0-2713-4318-9f39-0dfba07f4c2e.png" width="320">

3. アプリへ戻った直後。アラーム行が「許可済み」になり、設定誘導の文言と「設定を開く」が消えている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/2898534f-b71e-4bd4-a1b4-251e35177aba.png" width="320">

</details>

### **練習の録画にも上限とインジケーター**: 練習ステップの録画は朝の問いと同じ 10 秒の上限で自動停止し、録画中は同じ点 + タイマー「0:02 / 0:10」とリングで予告する (issue #71)。自動停止で練習完了「You're ready for the morning.」へ進む

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19** (iPhone 17 / iOS 26.5、simtunnel セッション `mementomorning-issue-71`、`--ref issue-71`、英語ロケール。commit `0ca3bfc`。開発者メニューで「動画回答を疑似再現」を ON → 「オンボーディングをリセット」→ 練習ステップ「Try it once」)

1. 録画開始から約 3 秒: 「0:02 / 0:10」と点、外リングの一部が夜明け色

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/5d71cbc4-de14-4ee1-a91a-cb0fa74e4628.jpg" width="320" />

2. 約 15 秒: ボタン操作なしで練習完了「You're ready for the morning.」へ進んでいる (10 秒で自動停止)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/21736772-7b95-4009-b5c7-7f8ea6614d52.jpg" width="320" />

</details>

</details>

---

## 2. 完了

- [x] **完了でホームへ**: アラーム設定ステップ (初期値 7:00) で保存するとオンボーディングが完了し、ホームへフェードで切り替わり、設定した時刻が NEXT MORNING に表示される
  - 自動化: manual（画面遷移と表示の確認）
- [x] **完了後は再表示しない**: 完了後にアプリを再起動してもオンボーディングは表示されず、ホームから始まる
  - 自動化: manual（アプリの再起動操作が必要）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **完了でホームへ**: アラーム設定ステップ (初期値 7:00) で保存するとオンボーディングが完了し、ホームへフェードで切り替わり、設定した時刻が NEXT MORNING に表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/7f66d9aa-375b-456c-b7a2-bdade68758f7.jpg" width="320">

</details>

### **完了後は再表示しない**: 完了後にアプリを再起動してもオンボーディングは表示されず、ホームから始まる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

新規インストールからオンボーディングを 7:00 で完了させたあと、`xcrun simctl terminate` → `launch` で再起動 (PID が 24291 → 64818 に変わっている) した直後の画面。オンボーディングを経ずにホーム (7:00 / 答えた日数 0 日) から始まっている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/55be5784-1f1f-47a7-81df-4e8471f44f28.png" width="320">

</details>

</details>

---
