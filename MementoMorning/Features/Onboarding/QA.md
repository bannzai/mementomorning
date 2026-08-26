---
feature: Onboarding
verification: mobile-mcp
last_verified_commit: eaa784897b4930279ea014af01b8e3887fac37a7
last_verified_at: 2026-08-22
---

# Onboarding QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/11 (受け入れ条件)
- 仕様: https://github.com/bannzai/mementomorning/issues/140 (課金転換型ファネルへの再設計。全 11 ステップの画面フローと確定コピー)
- 関連: なし

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 新規インストール → ペイン認識の 2 問 → 生まれ年 → 残りの朝 → メメント・モリ → 許可 → 練習 → アラーム設定 → 儀式のサマリー → ペイウォール、の一連が通る | 11 ステップの通し / ペイウォールを閉じてホームへ |
| S2 | 許可拒否時の導線 (設定アプリへの誘導) がある | 許可拒否時の設定誘導 |
| S3 | 生まれ年を答えなくても、78 歳以上でも残りの朝の画面が破綻しない | 残りの朝のフォールバック |
| S4 | ペイウォールの既存呼び出し (アラーム設定・カレンダー・回答ログ・開発者メニュー) は文脈行なしで従来どおり出る | ペイウォールの文脈行 |

## 1. ステップ進行

- [ ] **初回表示**: 新規インストール状態 (開発者メニューの Reset onboarding で再現) で起動すると、コンセプト提示「死を想ってから、朝を始める。」が表示される。ボタンは「はじめる」のみで、旧フローにあった補足「次の画面でアラームと通知の許可をお願いします」は表示されない (issue #140 で許可が次画面でなくなったため削除)
  - 自動化: manual（初回状態の作り込みと目視確認）
- [ ] **11 ステップの通し**: 「はじめる」(onboarding_begin) → スヌーズの質問 → 記憶の質問 → 生まれ年 → 残りの朝 → メメント・モリ → 許可ステップ (アラーム・通知の許可ダイアログ) → 回答の練習 → アラーム設定 → 儀式のサマリー → ペイウォール、の順にフェードで進む
  - 自動化: manual（OS 許可ダイアログの操作が必要）
  - 許可ダイアログの説明文: 英語ロケールで Info.plist に書いた用途説明文が表示される (issue #50 でキー名表示を解消済み)
- [ ] **プログレス表示**: スヌーズの質問から メメント・モリ までの 5 画面だけ、画面上部 (セーフエリア直下) に夜明け色の 1pt のラインが 1/5 → 5/5 と伸びる。コンセプト・許可以降・ペイウォールには出ない
  - 自動化: manual（描画の目視確認）
- [ ] **ペイン認識質問の回答が儀式サマリーに効く**: スヌーズの質問で「ほとんど毎朝」を選ぶとサマリーの一文が「もうスヌーズはいりません。アラームを止めるのは、あなたの答えだけ。」になる。スヌーズが「ほとんど毎朝」以外で記憶の質問が「ほとんど覚えていない」なら「明日からの朝は、残っていきます。」、どちらにも当てはまらなければ「明日の朝から、始まります。」
  - 自動化: manual（選択の組み合わせを変えて目視確認）
- [ ] **残りの朝のフォールバック**: 生まれ年で「答えずに進む」を選ぶ、または 78 歳以上になる生まれ年を選ぶと、回数を出さず「朝があと何回あるかは、誰にもわかりません。」「だからこそ、一回ごとに意味があります。」が表示される (計算の分岐は MementoMorningTests/OnboardingMorningsTests.swift がカバー済み)
  - 自動化: manual（ホイール操作と表示の目視確認）
- [x] **許可拒否時の設定誘導**: アラームまたは通知の許可を拒否すると、設定アプリへの誘導が表示される。設定アプリで許可して戻ると表示が追従する
  - 自動化: manual（画面上の導線の目視確認。誘導要否の判定ロジックは MementoMorningTests/OnboardingPermissionTests.swift がカバー済み）
  - 確認範囲: アラーム拒否経路 (通知許可) と通知拒否経路 (アラーム許可) の両方で、誘導表示と設定アプリからの復帰追従を確認済み
  - 設定アプリで**アラーム**の許可を変える手順: `UIApplication.openSettingsURLString` での遷移はシミュレータでは設定アプリのルートに着くため、「アプリ」→「MementoMorning」まで自分でたどる。その画面の「アラーム」トグルが AlarmKit の許可で、ON にしてステータスバー左上の「◀ MementoMorning」でアプリへ戻ると、OnboardingPage の scenePhase 監視が許可状態を再取得して表示が追従する
- [x] **練習の録画にも上限とインジケーター**: 練習ステップの録画は朝の問いと同じ 10 秒の上限で自動停止し、録画中は同じ点 + タイマー「0:02 / 0:10」とリングで予告する (issue #71)。自動停止で練習完了「You're ready for the morning.」へ進む
  - 自動化: manual（開発者メニューの疑似録画モードで simulator から確認。共通 View は MementoMorning/Features/MorningQuestion/VideoAnswerRecordingControls.swift）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

「(旧フロー)」の見出しは issue #140 の再設計より前 (コンセプト → 許可 → 練習 → アラーム設定 の 4 ステップ) に確認した記録。新フローの記録は run-qa で追記する。

### (旧フロー) **初回表示**: 新規インストール状態 (開発者メニューの Reset onboarding で再現) で起動すると、コンセプト提示「死を想ってから、朝を始める。」が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/8022b8d1-4207-46af-9b4f-ff83f8ee209b.jpg" width="320">

(simtunnel の新規インストール状態で確認。英語ロケールのため文言は「Remember death. Then begin your morning.」)

</details>

### (旧フロー) **3 ステップの通し**: 「はじめる」(onboarding_begin) → 許可ステップ (アラーム・通知の許可ダイアログ) → アラーム設定ステップ、の順にフェードで進む

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

**通知拒否経路の確認日: 2026-08-22** (ローカル simulator iPhone / iOS 26.5、日本語ロケール。`xcrun simctl uninstall` → `privacy reset all` → `install` の新規インストール状態から実施。アラームは「許可」、通知だけ「許可しない」を選んだ逆の経路)

1. 通知の許可ダイアログで「許可しない」を選んだ直後。「許可は設定アプリから変更できます」と「設定を開く」が現れ、夜のリマインド行だけ「許可済み」が付いていない (アラーム行には付いている)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/7e2c6f5f-fe6d-4b28-8808-d762c1837478.png" width="320">

2. 「設定を開く」→「MementoMorning」→「通知」で「通知を許可」を ON にした状態

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/faaab9e0-730c-4b67-ad0c-c7da6c298599.png" width="320">

3. アプリへ戻った直後。夜のリマインド行が「許可済み」になり、設定誘導の文言と「設定を開く」が消えている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/bbc0ce6e-c914-437a-ab1a-16009ef36efb.png" width="320">

アラームの許可 (`AlarmKitManager.authorizationState`) と違い、通知は `UNUserNotificationCenter.current().notificationSettings().authorizationStatus` から別途認可状態を取得する経路になっている。どちらも OnboardingPage の scenePhase 監視 (`.active` で `refreshPermissionStates()`) で読み直されるため、設定アプリからの復帰で表示が追従する

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

- [ ] **アラーム設定の保存で儀式のサマリーへ**: アラーム設定ステップ (初期値 7:00) で保存すると、ホームではなく儀式のサマリーへフェードで進み、1 行目に設定した時刻 (7:00) が入る
  - 自動化: manual（画面遷移と表示の確認）
- [ ] **ペイウォールの文脈行**: 儀式のサマリーの「はじめる」(onboarding_summary_begin) でペイウォールが全画面表示され、生まれ年を答えている場合だけタイトルの上に夜明け色で「残りは約 N 回の朝。そのすべてを、残すために。」が出る。生まれ年をスキップした場合と、既存の呼び出し (アラーム設定・カレンダー・回答ログ・開発者メニュー) では出ない
  - 自動化: manual（表示の目視確認）
- [ ] **ペイウォールを閉じてホームへ**: ペイウォールを「今はしない」(paywall_not_now_button)・購入・復元のいずれで閉じてもオンボーディングが完了し、ホームへ切り替わって設定した時刻が表示される
  - 自動化: manual（購入・復元は RevenueCat Test Store で確認する）
- [ ] **完了後は再表示しない**: 完了後にアプリを再起動してもオンボーディングは表示されず、ホームから始まる
  - 自動化: manual（アプリの再起動操作が必要）
- [ ] **オンボーディングのリセットが冪等**: 開発者メニューの「オンボーディングをリセット」で完了フラグとオンボーディング内の回答 (生まれ年・ペイン認識 2 問) が消え、再走すると生まれ年ホイールが初期値に戻る。何度押しても同じ状態になる
  - 自動化: manual（開発者メニュー操作と再走の確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### (旧フロー) **完了でホームへ**: アラーム設定ステップ (初期値 7:00) で保存するとオンボーディングが完了し、ホームへフェードで切り替わり、設定した時刻が NEXT MORNING に表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/7f66d9aa-375b-456c-b7a2-bdade68758f7.jpg" width="320">

</details>

### (旧フロー) **完了後は再表示しない**: 完了後にアプリを再起動してもオンボーディングは表示されず、ホームから始まる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

新規インストールからオンボーディングを 7:00 で完了させたあと、`xcrun simctl terminate` → `launch` で再起動 (PID が 24291 → 64818 に変わっている) した直後の画面。オンボーディングを経ずにホーム (7:00 / 答えた日数 0 日) から始まっている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/55be5784-1f1f-47a7-81df-4e8471f44f28.png" width="320">

</details>

</details>

---
