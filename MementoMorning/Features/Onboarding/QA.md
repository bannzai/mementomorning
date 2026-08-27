---
feature: Onboarding
verification: mobile-mcp
last_verified_commit: d40bf8d
last_verified_at: 2026-08-27
---

# Onboarding QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/11 (受け入れ条件)
- 仕様: https://github.com/bannzai/mementomorning/issues/140 (課金転換型ファネルへの再設計。全 14 ステップの画面フローと確定コピー。うち質問 3 画面は追加実装で加わった)
- 仕様: https://github.com/bannzai/mementomorning/issues/144 (オンボーディングの見直し。アラーム設定と儀式のサマリーの間に、長押しで約束を交わすコミットメントのステップを追加して全 15 ステップにした)
- 関連: なし

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 新規インストール → ペイン認識の 5 問 → 生まれ年 → 残りの朝 → メメント・モリ → 許可 → 練習 → アラーム設定 → 明日への約束 → 儀式のサマリー → ペイウォール、の一連が通る | 15 ステップの通し / 明日への約束の長押し / ペイウォールを閉じてホームへ |
| S2 | 許可拒否時の導線 (設定アプリへの誘導) がある | 許可拒否時の設定誘導 |
| S3 | 生まれ年を答えなくても、78 歳以上でも残りの朝の画面が破綻しない | 残りの朝のフォールバック |
| S4 | ペイウォールの既存呼び出し (アラーム設定・カレンダー・回答ログ・開発者メニュー) は文脈行なしで従来どおり出る | ペイウォールの文脈行 |

## 1. ステップ進行

- [x] **初回表示**: 新規インストール状態 (開発者メニューの Reset onboarding で再現) で起動すると、コンセプト提示「死を想ってから、朝を始める。」が表示される。ボタンは「はじめる」のみで、旧フローにあった補足「次の画面でアラームと通知の許可をお願いします」は表示されない (issue #140 で許可が次画面でなくなったため削除)
  - 自動化: manual（初回状態の作り込みと目視確認）
- [ ] **15 ステップの通し**: 「はじめる」(onboarding_begin) → 起床の質問「朝は一度のアラームで起きられますか？」→ 満足の質問「いまの朝の迎え方に満足していますか？」→ 起きてすぐの過ごし方の質問 → 一日が始まる時間帯の質問 → 手つかずの「いつか」の質問 → 生まれ年 → 残りの朝 → メメント・モリ → 許可ステップ (アラーム・通知の許可ダイアログ) → 回答の練習 → アラーム設定 → 明日への約束 → 儀式のサマリー → ペイウォール、の順にフェードで進む
  - 自動化: manual（OS 許可ダイアログの操作が必要）
  - 許可ダイアログの説明文: 英語ロケールで Info.plist に書いた用途説明文が表示される (issue #50 でキー名表示を解消済み)
- [x] **プログレス表示**: 起床の質問から メメント・モリ までの 8 画面だけ、画面上部 (セーフエリア直下) に夜明け色の 1pt のラインが 1/8 → 8/8 と伸びる。コンセプト・許可以降 (明日への約束を含む)・ペイウォールには出ない
  - 自動化: manual（描画の目視確認）
- [ ] **明日への約束の長押し**: アラーム設定の保存後、見出し「明日の自分に、ひとつの約束」と宣誓文「明日の 7:00、私は目を覚まし、自分と向き合い、答えます。」(設定した時刻が入る) が表示され、リング (onboarding_pledge_hold) の下に「長押しで約束する」が出る。リングを 1.2 秒以上長押しすると夜明け色のリングが満ちて案内が「約束しました」に変わり、約 0.8 秒後に儀式のサマリーへフェードで進む。1.2 秒未満で指を離すとリングは戻り、進まない。「つづける」などのボタンは無く、長押し以外で進む導線は無い
  - 自動化: manual（長押しの時間と描画の目視確認。mobile-mcp の long_press は duration 2000 (ms) 以上、ios-wda.sh は `longpress <x> <y> 2000` で成立させる。短押しの検証は通常の tap で行う）
- [x] **ペイン認識質問の回答が儀式サマリーに効く**: 5 問の回答から次の優先順で最初に該当した一文だけがサマリーに出る。(1) 手つかずの「いつか」が「あるが手つかずのまま」→「明日の朝はその「いつか」に答えてください」 (2) 起床が「ほとんど起きられない」→「もうスヌーズはいりません」(改行)「アラームを止めるのはあなたの答えだけ」 (3) 満足が「満足していない」→「明日から胸を張れる朝を」 (4) 一日の始まりが「夕方になってようやく」→「明日からあなたの一日は朝に始まります」 (5) 起きてすぐが「スマホを眺めている」→「明日の最初の数分はスマホではなく問いのために」 (6) どれにも当てはまらない→「明日の朝から始まります」
  - 自動化: manual（選択の組み合わせを変えて目視確認。選択ロジック自体は MementoMorningTests/OnboardingMorningsTests.swift の RitualSummaryNoteTests がカバー済み）
- [x] **残りの朝の問いかけと誘い**: 残りの朝の画面で、回数が出る場合は「あなたはこれまでに約 N 回の朝を迎えました」「残りは約 N 回」「そのどれも二度は来ません」の下に、回数が出ない場合は「朝があと何回あるかは誰にもわかりません」「だからこそ一回ごとに意味があります」の下に、「あなたが本当に迎えたかった朝はどんな朝ですか」「明日から気力の満ちる朝を迎えましょう」の 2 行が同じ控えめな様式 (12pt・opacity 0.45) で常に出る。ペイン認識質問の回答による出し分けはない
  - 自動化: manual（回数が出る通しと出ない通しの両方で目視確認）
- [x] **残りの朝のフォールバック**: 生まれ年で「答えずに進む」を選ぶ、または 78 歳以上になる生まれ年を選ぶと、回数を出さず「朝があと何回あるかは誰にもわかりません」「だからこそ一回ごとに意味があります」が表示される (計算の分岐は MementoMorningTests/OnboardingMorningsTests.swift がカバー済み)
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

### **初回表示**: 新規インストール状態 (開発者メニューの Reset onboarding で再現) で起動すると、コンセプト提示「死を想ってから、朝を始める。」が表示される。ボタンは「はじめる」のみで、旧フローにあった補足「次の画面でアラームと通知の許可をお願いします」は表示されない (issue #140 で許可が次画面でなくなったため削除)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** (ローカル simulator mementomorning-sktest-iOS26.2 / iOS 26.2、日本語ロケール、commit `2577aab`。開発者メニューの「オンボーディングをリセット」直後)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/1adf8bff-a6e0-4a18-b83f-59dd456b1c27.png" width="320">

ボタンは「はじめる」だけで、旧フローの補足「次の画面でアラームと通知の許可をお願いします」は消えている。見出しの下の「毎朝ひとつの問いに答えて、アラームを止める。答えは、あなたの人生のジャーナルになる。」は issue #140 で新しく入れたコピーで、許可の予告ではない

</details>

### (質問 3 画面の追加前) **11 ステップの通し**: 「はじめる」(onboarding_begin) → スヌーズの質問 → 記憶の質問 → 生まれ年 → 残りの朝 → メメント・モリ → 許可ステップ (アラーム・通知の許可ダイアログ) → 回答の練習 → アラーム設定 → 儀式のサマリー → ペイウォール、の順にフェードで進む

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** (ローカル simulator mementomorning-sktest-iOS26.2 / iOS 26.2、日本語ロケール、commit `2577aab`。maestro で「ほとんど毎朝」「ほとんど覚えていない」「1987 年」を選んで通した)

スヌーズの質問 → 記憶の質問 → 生まれ年 → 残りの朝 → メメント・モリ

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/c4ffdca8-992f-409d-9cac-12d2e0a1449b.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/64188892-cc9d-4695-962a-43094cc16f1f.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/727463bf-3ebf-4b1e-917b-ad3e2119bcd5.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/0837bc06-6bff-4646-ad4a-475898b4d597.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/9a8a4197-ba58-4608-b6ef-c8d4370f385c.png" width="320">

許可 → アラーム設定 → 儀式のサマリー → ペイウォール → ホーム

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/1370c942-fea2-4b84-8227-5687d33f0af6.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/7641494c-012b-48a6-869c-d5c1669fcd08.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/e5861815-0392-40b1-b39f-454499c9a5d5.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/627624a6-a48f-4092-9de5-b968d6470cc0.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/37e65478-f641-4458-9dbf-cbd7b1324403.png" width="320">

先頭のコンセプト画面は上の「初回表示」のスクショを参照 (別実行で撮影)。回答の練習は「あとでやる」で飛ばしている。許可ステップではアラームと通知の 2 つの OS ダイアログが出て、どちらも「許可」で進んだ

残りの朝で「これまで 約 14,235 回」と「残りは 約 14,235 回」が同じ数になるのは、1987 年生まれ = 39 歳が計算に使う平均寿命 78 歳のちょうど半分だからで、不具合ではない。ホームのスクショに重なっている「Apple Account にサインイン」はこのシミュレータが定期的に出すもので、アプリとは無関係

</details>

### (質問 3 画面の追加前) **プログレス表示**: スヌーズの質問から メメント・モリ までの 5 画面だけ、画面上部 (セーフエリア直下) に夜明け色の 1pt のラインが 1/5 → 5/5 と伸びる。コンセプト・許可以降・ペイウォールには出ない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27**

スヌーズの質問 (1/5。画面幅の 5 分の 1 まで伸びている) / メメント・モリ (5/5。画面幅いっぱい) / 許可ステップ (ラインが出ない)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/c4ffdca8-992f-409d-9cac-12d2e0a1449b.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/9a8a4197-ba58-4608-b6ef-c8d4370f385c.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/1370c942-fea2-4b84-8227-5687d33f0af6.png" width="320">

コンセプト (上の「初回表示」のスクショ) とペイウォール (下の「ペイウォールの文脈行」のスクショ) にもラインは出ていない

</details>

### (質問 3 画面の追加前) **ペイン認識質問の回答が儀式サマリーに効く**: スヌーズの質問で「ほとんど毎朝」を選ぶとサマリーの一文が「もうスヌーズはいりません。アラームを止めるのは、あなたの答えだけ。」になる。スヌーズが「ほとんど毎朝」以外で記憶の質問が「ほとんど覚えていない」なら「明日からの朝は、残っていきます。」、どちらにも当てはまらなければ「明日の朝から、始まります。」

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** 3 通りの組み合わせをそれぞれ別の通しで確認した

1. スヌーズ「ほとんど毎朝」→「もうスヌーズはいりません。アラームを止めるのは、あなたの答えだけ。」

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/e5861815-0392-40b1-b39f-454499c9a5d5.png" width="320">

2. スヌーズ「ときどき」+ 記憶「ほとんど覚えていない」→「明日からの朝は、残っていきます。」

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/5a5f3358-3de5-4cb3-96e4-88c912c7893e.png" width="320">

3. スヌーズ「ときどき」+ 記憶「いくつかは」→「明日の朝から、始まります。」

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/f11f05ed-12d5-4f2e-9885-d3c462d9e846.png" width="320">

</details>

### (文言改定前) **残りの朝のフォールバック**: 生まれ年で「答えずに進む」を選ぶ、または 78 歳以上になる生まれ年を選ぶと、回数を出さず「朝があと何回あるかは、誰にもわかりません。」「だからこそ、一回ごとに意味があります。」が表示される (計算の分岐は MementoMorningTests/OnboardingMorningsTests.swift がカバー済み)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** 生まれ年で「答えずに進む」(onboarding_birth_year_skip) を選んだ時。回数を出さず「朝があと何回あるかは、誰にもわかりません。」「だからこそ、一回ごとに意味があります。」になっている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/bde203f9-f6da-483a-87d2-d5d742d26b3e.png" width="320">

78 歳以上になる生まれ年の経路は UI では通していない。生まれ年のスキップ (birthYear = 0) と 78 歳以上はどちらも `morningsResultVariant` が同じ `.unknown` を返す分岐で、78 歳の側は MementoMorningTests/OnboardingMorningsTests.swift の `morningsResultVariant(birthYear: 2026 - 78, currentYear: 2026) == .unknown` がカバーしている。表示は上のスクショと同一になる

</details>

### (文言改定前) **14 ステップの通し**: 「はじめる」(onboarding_begin) → スヌーズの質問 → 記憶の質問 → 目覚めてすぐの過ごし方の質問 → 一日が始まる時間帯の質問 → 手つかずの「いつか」の質問 → 生まれ年 → 残りの朝 → メメント・モリ → 許可ステップ (アラーム・通知の許可ダイアログ) → 回答の練習 → アラーム設定 → 儀式のサマリー → ペイウォール、の順にフェードで進む

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** (ローカル simulator mementomorning-sktest-iOS26.2 / iOS 26.2、日本語ロケール、commit `468ad17` のビルドを入れ直して実施。maestro で「ときどき」「いくつかは」「スマホを眺めている」「夕方になってようやく」「ある。手つかずのまま」「1987 年」を選んで通した)

追加された質問 3 画面。目覚めてすぐの過ごし方 → 一日が始まる時間帯 → 手つかずの「いつか」の順で、スヌーズ・記憶の 2 問と同じ様式 (問い + 3 択) で入っている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/41007318-2625-4985-be88-fabc06f335d9.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/55958b29-bb40-440d-a58f-ccdb97656f37.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/41858268-a121-47ae-9cf4-fc3d9bf567aa.png" width="320">

3 画面の前後。スヌーズの質問 (3 画面の直前) → 残りの朝 → メメント・モリ → 儀式のサマリー → ペイウォール → ホーム

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/afc82b33-768c-4f52-85ec-ea2bc7e52583.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/6a34fbb1-67f2-469e-9c23-e6bd12c61cfa.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/f2b42d9e-c5aa-40cc-854d-640124437c0d.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/6b715091-cbef-4233-923d-c3703109167d.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/2ffb6087-00b1-4c18-85a0-28b2f834b09a.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/1c6ed8b7-1ab4-4b06-a301-2bbfae1cae46.png" width="320">

コンセプト・記憶の質問・生まれ年・許可・練習・アラーム設定は 3 画面の追加で変わっておらず、スクショは上の「(質問 3 画面の追加前) 11 ステップの通し」と「初回表示」を参照。回答の練習は「あとでやる」で飛ばしている。ホームの「答えた日数 1 日」は、7:00 のアラーム時刻を過ぎていてアプリが今朝の問いで止まっていたため、通しの前準備としてテキストで回答したことによるもの (オンボーディングとは無関係)

</details>

### (文言改定前) **プログレス表示**: スヌーズの質問から メメント・モリ までの 8 画面だけ、画面上部 (セーフエリア直下) に夜明け色の 1pt のラインが 1/8 → 8/8 と伸びる。コンセプト・許可以降・ペイウォールには出ない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27**

スヌーズの質問 (1/8。画面幅の 8 分の 1) / 目覚めてすぐの過ごし方 (3/8) / 残りの朝 (7/8) / メメント・モリ (8/8。画面幅いっぱい)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/afc82b33-768c-4f52-85ec-ea2bc7e52583.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/41007318-2625-4985-be88-fabc06f335d9.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/6a34fbb1-67f2-469e-9c23-e6bd12c61cfa.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/f2b42d9e-c5aa-40cc-854d-640124437c0d.png" width="320">

コンセプト (リセット直後のスクショ) と儀式のサマリー・ペイウォール (上の 14 ステップの通しのスクショ) にはラインが出ていない

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/f0e113a0-6923-4998-a277-3f8d85551d9f.png" width="320">

</details>

### (文言改定前) **ペイン認識質問の回答が儀式サマリーに効く**: 5 問の回答から次の優先順で最初に該当した一文だけがサマリーに出る。(1) 手つかずの「いつか」が「ある。手つかずのまま」→「明日の朝、その「いつか」に答えてください。」 (2) スヌーズが「ほとんど毎朝」→「もうスヌーズはいりません。アラームを止めるのは、あなたの答えだけ。」 (3) 記憶が「ほとんど覚えていない」→「明日からの朝は、残っていきます。」 (4) 一日の始まりが「夕方になってようやく」→「明日から、あなたの一日は朝に始まります。」 (5) 目覚めてすぐが「スマホを眺めている」→「明日の最初の数分は、スマホではなく問いのために。」 (6) どれにも当てはまらない→「明日の朝から、始まります。」

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** 質問 3 画面の追加で増えた 3 通りを、それぞれ別の通しで確認した

1. 手つかずの「いつか」が「ある。手つかずのまま」(スヌーズ「ときどき」+ 記憶「いくつかは」) →「明日の朝、その「いつか」に答えてください。」

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/6b715091-cbef-4233-923d-c3703109167d.png" width="320">

2. 一日の始まりが「夕方になってようやく」(上位 3 つに当てはまらない組み合わせ。スヌーズ「ときどき」+ 記憶「いくつかは」+ 目覚めてすぐ「朝の習慣がある」+ 手つかずの「いつか」「特にない」) →「明日から、あなたの一日は朝に始まります。」

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/b8751ff2-0f2d-41d9-9a54-f8827837a28a.png" width="320">

3. 目覚めてすぐが「スマホを眺めている」だけ該当 (一日の始まり「朝から」+ 手つかずの「いつか」「特にない」) →「明日の最初の数分は、スマホではなく問いのために。」

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/9ce65068-0c6e-46ef-88dc-578ae3137cb9.png" width="320">

4. どれにも当てはまらない (目覚めてすぐ「朝の習慣がある」+ 一日の始まり「朝から」+ 手つかずの「いつか」「特にない」) →「明日の朝から、始まります。」

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/a65d6e7c-5b82-4c98-9e1c-96ef669fdae6.png" width="320">

残る 2 通り、スヌーズ「ほとんど毎朝」の「もうスヌーズはいりません。アラームを止めるのは、あなたの答えだけ。」と、記憶「ほとんど覚えていない」の「明日からの朝は、残っていきます。」は、質問 3 画面の追加前 (11 ステップ時点) の記録が有効。上の「(質問 3 画面の追加前) ペイン認識質問の回答が儀式サマリーに効く」を参照。優先順の選択ロジック自体は純関数 `ritualSummaryNote` で、MementoMorningTests/OnboardingMorningsTests.swift の RitualSummaryNoteTests が 6 通りの一文それぞれと、優先順の逆転がないこと (手つかずの「いつか」> スヌーズ > 記憶 > 一日の始まり > 目覚めてすぐ) をカバーしている

</details>

### (文言改定前・項目廃止) **残りの朝の追い打ちの一文**: 手つかずの「いつか」の質問で「ある。手つかずのまま」を選んだ場合だけ、残りの朝の画面で「そのどれも、二度は来ません。」の下に「そのうち何回を、「いつか」のままにしますか？」が同じ控えめな様式で出る。他の回答では出ない。生まれ年をスキップして回数が出ていない場合は、回答に関わらず出ない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27**

1. 手つかずの「いつか」が「ある。手つかずのまま」+ 生まれ年 1987。「そのどれも、二度は来ません。」の下に「そのうち何回を、「いつか」のままにしますか？」が、同じ大きさ・同じ控えめな明度で出ている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/6a34fbb1-67f2-469e-9c23-e6bd12c61cfa.png" width="320">

2. 手つかずの「いつか」が「特にない」+ 生まれ年 1987。追い打ちの一文が出ていない (maestro の assertNotVisible でも確認)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/26409380-db42-4e26-9688-52517ac0cbb4.png" width="320">

3. 手つかずの「いつか」が「ある。手つかずのまま」+ 生まれ年をスキップ。回数が出ないため追い打ちの一文も出ていない (同じく assertNotVisible で確認)。この通しの儀式サマリーは「明日の朝、その「いつか」に答えてください。」のままで、回答自体は保持されている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/e76b26a6-ea8b-467b-a368-f6afd6b08fdf.png" width="320">

</details>

### **14 ステップの通し**: 「はじめる」(onboarding_begin) → 起床の質問「朝は一度のアラームで起きられますか？」→ 満足の質問「いまの朝の迎え方に満足していますか？」→ 起きてすぐの過ごし方の質問 → 一日が始まる時間帯の質問 → 手つかずの「いつか」の質問 → 生まれ年 → 残りの朝 → メメント・モリ → 許可ステップ (アラーム・通知の許可ダイアログ) → 回答の練習 → アラーム設定 → 儀式のサマリー → ペイウォール、の順にフェードで進む

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** (文言改定後の再確認。ローカル simulator mementomorning-sktest-iOS26.2 / iOS 26.2、日本語ロケール、commit `0832538`。maestro フロー tmp/copyqa-flowA1/A2.yaml で新規状態から通し、実行ログは ./tmp/qa2/)

起床の質問 → 満足の質問 → 起きてすぐの過ごし方 → 一日が始まる時間帯 → 手つかずの「いつか」→ 生まれ年 → 残りの朝 → メメント・モリ → 許可、の順にフェードで進み、各画面が改定後の文言 (読点なし) で表示されている。許可以降 → 練習スキップ → アラーム設定 → 儀式のサマリー → ペイウォールも同じ通しで確認 (スクショは下の「ペイン認識質問の回答が儀式サマリーに効く」「ペイウォールの文脈行」を参照)

**確認日: 2026-08-27** (追記: 儀式サマリー 3 行目を「夜は朝の回答と一日の答え合わせ」へ変更した commit `d40bf8d` で、同じ maestro フロー 4 本 (ログ ./tmp/qa3/) を再走して全パス。変更行が新文言で表示されている)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/098e2618-526d-4fe9-82c2-d18d7cbb8db0.png" width="300" />

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/1140f598-4108-4552-92db-c143362a8062.png" width="300" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/43f11eca-0415-494a-b6d5-8ea09e5ff6e4.png" width="300" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/d7257730-3a94-448d-b55e-a2966430d9fe.png" width="300" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/3ebe8635-399b-4752-997e-25973b603fac.png" width="300" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/56f9b051-54b5-48f4-9c78-38a1fed68358.png" width="300" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/74418b72-75b4-444a-b2fa-fa6e23ce6b6c.png" width="300" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/6d5e0f21-843f-49fd-b4d5-40fcb9232fff.png" width="300" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/c27e5e3c-22d8-4d16-b23c-d7692352f000.png" width="300" />

</details>

### **プログレス表示**: 起床の質問から メメント・モリ までの 8 画面だけ、画面上部 (セーフエリア直下) に夜明け色の 1pt のラインが 1/8 → 8/8 と伸びる。コンセプト・許可以降・ペイウォールには出ない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** (文言改定後の再確認。commit `0832538`。挙動自体は変更なしで、上の 14 ステップの通しのスクショで確認)

起床の質問 (1/8。画面幅の 8 分の 1) / 起きてすぐの過ごし方 (3/8) / 残りの朝 (7/8) / メメント・モリ (8/8。画面幅いっぱい)。許可ステップにはラインが出ない

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/1140f598-4108-4552-92db-c143362a8062.png" width="300" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/d7257730-3a94-448d-b55e-a2966430d9fe.png" width="300" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/6d5e0f21-843f-49fd-b4d5-40fcb9232fff.png" width="300" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/c27e5e3c-22d8-4d16-b23c-d7692352f000.png" width="300" />

</details>

### **ペイン認識質問の回答が儀式サマリーに効く**: 5 問の回答から次の優先順で最初に該当した一文だけがサマリーに出る。(1) 手つかずの「いつか」が「あるが手つかずのまま」→「明日の朝はその「いつか」に答えてください」 (2) 起床が「ほとんど起きられない」→「もうスヌーズはいりません」(改行)「アラームを止めるのはあなたの答えだけ」 (3) 満足が「満足していない」→「明日から胸を張れる朝を」 (4) 一日の始まりが「夕方になってようやく」→「明日からあなたの一日は朝に始まります」 (5) 起きてすぐが「スマホを眺めている」→「明日の最初の数分はスマホではなく問いのために」 (6) どれにも当てはまらない→「明日の朝から始まります」

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** (文言改定後の再確認。commit `0832538`。maestro フロー tmp/copyqa-flowA2/B/C.yaml)

1. 手つかずの「いつか」が「あるが手つかずのまま」(起床「ほとんど起きられない」+ 満足「満足していない」) →「明日の朝はその「いつか」に答えてください」

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/90f091a0-88e7-4a64-bd8c-ddb36917ca60.png" width="300" />

2. 起床が「ほとんど起きられない」(手つかずの「いつか」は「特にない」) →「もうスヌーズはいりません」(改行)「アラームを止めるのはあなたの答えだけ」の 2 行

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/89d32eb7-a8b4-4f03-b6e6-c360ed109212.png" width="300" />

3. 満足が「満足していない」(起床「ときどき」+ 手つかずの「いつか」「特にない」) →「明日から胸を張れる朝を」

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/337a7efc-5559-4e5d-a4db-94422993015b.png" width="300" />

残る 3 分岐 (一日の始まり・起きてすぐ・どれにも当てはまらない) は、目視 3 分岐と同じ noteText の switch と同じ 12pt の様式で描画され、優先順の選択ロジックは純関数 `ritualSummaryNote` を MementoMorningTests/OnboardingMorningsTests.swift の RitualSummaryNoteTests (改定後の enum・文言に追随済み) が 6 分岐 + 優先順の逆転なしでカバーしている

</details>

### **残りの朝の問いかけと誘い**: 残りの朝の画面で、回数が出る場合は「あなたはこれまでに約 N 回の朝を迎えました」「残りは約 N 回」「そのどれも二度は来ません」の下に、回数が出ない場合は「朝があと何回あるかは誰にもわかりません」「だからこそ一回ごとに意味があります」の下に、「あなたが本当に迎えたかった朝はどんな朝ですか」「明日から気力の満ちる朝を迎えましょう」の 2 行が同じ控えめな様式 (12pt・opacity 0.45) で常に出る。ペイン認識質問の回答による出し分けはない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** (commit `0832538`。maestro フロー tmp/copyqa-flowA1/B.yaml。assertVisible + スクショの目視で確認)

1. 生まれ年 1987 (回数あり)。「そのどれも二度は来ません」の下に問いかけと誘いの 2 行が同じ控えめな様式で出ている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/6d5e0f21-843f-49fd-b4d5-40fcb9232fff.png" width="300" />

2. 生まれ年をスキップ (回数不明)。「だからこそ一回ごとに意味があります」の下に同じ 2 行が出ている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/faccf402-cae5-45ee-a932-5063915121cc.png" width="300" />

</details>

### **残りの朝のフォールバック**: 生まれ年で「答えずに進む」を選ぶ、または 78 歳以上になる生まれ年を選ぶと、回数を出さず「朝があと何回あるかは誰にもわかりません」「だからこそ一回ごとに意味があります」が表示される (計算の分岐は MementoMorningTests/OnboardingMorningsTests.swift がカバー済み)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** (文言改定後の再確認。commit `0832538`。maestro フロー tmp/copyqa-flowB.yaml)

「答えずに進む」で回数を出さず、改定後の文言 (読点なし) で 2 行が表示されている。78 歳以上の分岐は計算の分岐ごと MementoMorningTests/OnboardingMorningsTests.swift がカバー (表示文言は同じ .unknown)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/faccf402-cae5-45ee-a932-5063915121cc.png" width="300" />

</details>

</details>

---

## 2. 完了

- [ ] **アラーム設定の保存で明日への約束、そして儀式のサマリーへ**: アラーム設定ステップ (初期値 7:00) で保存すると、ホームではなく明日への約束へフェードで進み、宣誓文に設定した時刻 (7:00) が入る。約束の成立で儀式のサマリーへ進み、1 行目にも同じ時刻が入る
  - 自動化: manual（画面遷移と表示の確認）
- [x] **ペイウォールの文脈行**: 儀式のサマリーの「はじめる」(onboarding_summary_begin) でペイウォールが全画面表示され、生まれ年を答えている場合だけ見出し「すべての朝を残すために」の上に夜明け色で「残り約 N 回の朝をすべて残すために」が出る。生まれ年をスキップした場合と、既存の呼び出し (アラーム設定・カレンダー・回答ログ・開発者メニュー) では出ない
  - 自動化: manual（表示の目視確認）
- [x] **ペイウォールを閉じてホームへ**: ペイウォールを「今はしない」(paywall_not_now_button)・購入・復元のいずれで閉じてもオンボーディングが完了し、ホームへ切り替わって設定した時刻が表示される
  - 自動化: manual（購入・復元は RevenueCat Test Store で確認する）
- [x] **完了後は再表示しない**: 完了後にアプリを再起動してもオンボーディングは表示されず、ホームから始まる
  - 自動化: manual（アプリの再起動操作が必要）
- [x] **オンボーディングのリセットが冪等**: 開発者メニューの「オンボーディングをリセット」で完了フラグとオンボーディング内の回答 (生まれ年・ペイン認識 5 問) が消え、再走すると生まれ年ホイールが初期値に戻る。何度押しても同じ状態になる
  - 自動化: manual（開発者メニュー操作と再走の確認）
- [x] **サマリー・ペイウォール表示中の kill で再走する**: アラーム保存後、明日への約束・儀式のサマリー・ペイウォールの表示中にアプリを終了して再起動すると、完了扱いでホームへ飛ばず、オンボーディングがコンセプトから再走する。アラーム設定ステップには保存済みの時刻が復元される
  - 自動化: manual（アプリの強制終了と再起動が必要）

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

### **アラーム設定の保存で儀式のサマリーへ**: アラーム設定ステップ (初期値 7:00) で保存すると、ホームではなく儀式のサマリーへフェードで進み、1 行目に設定した時刻 (7:00) が入る

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** (ローカル simulator mementomorning-sktest-iOS26.2 / iOS 26.2、日本語ロケール、commit `2577aab`)

アラーム設定ステップ (7:00) で「アラームをセットする」を押すと、ホームではなく儀式のサマリーへ進み、1 行目が「7:00 — アラームが鳴る」になっている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/7641494c-012b-48a6-869c-d5c1669fcd08.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/e5861815-0392-40b1-b39f-454499c9a5d5.png" width="320">

</details>

### (文言改定前) **ペイウォールの文脈行**: 儀式のサマリーの「はじめる」(onboarding_summary_begin) でペイウォールが全画面表示され、生まれ年を答えている場合だけタイトルの上に夜明け色で「残りは約 N 回の朝。そのすべてを、残すために。」が出る。生まれ年をスキップした場合と、既存の呼び出し (アラーム設定・カレンダー・回答ログ・開発者メニュー) では出ない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27**

1. 生まれ年 1987 を答えた通し。タイトルの上に夜明け色で「残りは約 14,235 回の朝。そのすべてを、残すために。」が出ている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/627624a6-a48f-4092-9de5-b968d6470cc0.png" width="320">

2. 生まれ年を「答えずに進む」で飛ばした通し。文脈行は出ない

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/5275d0e1-de57-4d4e-afdf-ebb764d89e7b.png" width="320">

3. 既存の呼び出し (開発者メニューの「ペイウォールを開く」)。文脈行は出ない

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/679c48db-8a49-4ba4-8f41-d43c0785572e.png" width="320">

アラーム設定・カレンダー・回答ログからの呼び出しは、開発者メニューと同じく引数なしの `PaywallPage()` (`remainingMorningsCount` は既定値 nil) で、文脈行を出す経路はオンボーディングの `PaywallPage(remainingMorningsCount:)` だけのため、既存呼び出しの代表として開発者メニューの経路で確認した

</details>

### **ペイウォールを閉じてホームへ**: ペイウォールを「今はしない」(paywall_not_now_button)・購入・復元のいずれで閉じてもオンボーディングが完了し、ホームへ切り替わって設定した時刻が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** 「今はしない」(paywall_not_now_button) で閉じた場合。オンボーディングが完了してホームへ切り替わり、設定した 7:00 が出ている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/102926e2-5e72-4685-83d4-9f94a7c1aed4.png" width="320">

**確認日: 2026-08-27** 購入で閉じた場合 (RevenueCat Test Store。Debug ビルドの既定 API key)

年額ボタン (paywall_yearly_button) を押すと Test Store の購入モーダルが出る。商品は `mementomorning_premium_annual` / $38.00 / SubscriptionPeriod 1 year で、ペイウォールの表示と一致している

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/006f13dc-4016-401a-9145-ad4b976b98ef.png" width="320">

「Test valid purchase」で購入を確定すると、ペイウォールが閉じて (paywall_not_now_button が無いことを assertNotVisible で確認) オンボーディングが完了し、ホームへ切り替わって設定した 7:00 が出ている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/4de0158f-19ea-4f67-83d9-0a6a4d44c09b.png" width="320">

ペイウォールが閉じただけでなく entitlement premium が実際に有効になっている。アプリを再起動した後の開発者メニューで「プレミアム判定 (isPremium): true」になっており、「プレミアムを強制 (上書き)」のトグルは OFF のままなので、デバッグの上書きではなく購入による付与である

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/e864f247-3109-4119-b2ba-6f5d14585f17.png" width="320">

**確認日: 2026-08-27** 復元で閉じた場合 (上の購入を済ませたシミュレータで、オンボーディングをリセットしてから実施)

ペイウォールの「購入を復元」(paywall_restore) をタップした場合

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/f9189c0f-88fb-49ac-8692-b82af2e4f056.png" width="320">

「復元できる購入が見つかりませんでした」等のアラートは出ず、ペイウォールが閉じて (paywall_not_now_button が無いことを assertNotVisible で確認) オンボーディングが完了し、ホームへ切り替わって設定した 7:00 が出ている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/6922add9-9471-43ae-9138-b2ec24a09e0c.png" width="320">

これで「今はしない」・購入・復元の 3 経路とも実測した。`restore()` は entitlement のキャッシュではなく `Purchases.shared.restorePurchases()` の戻り値で判定するため、この復元はキャッシュ済みの状態に引きずられたものではなく Test Store の復元結果によるもの

</details>

### **完了後は再表示しない**: 完了後にアプリを再起動してもオンボーディングは表示されず、ホームから始まる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** オンボーディング完了後に maestro の launchApp でアプリを再起動した直後。コンセプト画面の「はじめる」(onboarding_begin) が無いことを assertNotVisible で確かめた上で撮影している

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/74d109f3-6d0f-4aa1-b824-a1cb7762f3c0.png" width="320">

同じ再起動を別実行で撮った次のスクショには「Apple Account にサインイン」が重なっているが、これはこのシミュレータが定期的に出すもので、アプリとは無関係

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/8fed2f69-735d-491a-8a24-e25f41b43caa.png" width="320">

</details>

### (質問 3 画面の追加前) **オンボーディングのリセットが冪等**: 開発者メニューの「オンボーディングをリセット」で完了フラグとオンボーディング内の回答 (生まれ年・ペイン認識 2 問) が消え、再走すると生まれ年ホイールが初期値に戻る。何度押しても同じ状態になる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** 開発者メニューの「オンボーディングをリセット」を 2 回実行し、どちらも同じコンセプト画面から再走できた

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/1adf8bff-a6e0-4a18-b83f-59dd456b1c27.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/4d3dcfe1-1e8c-47d1-bbcb-1bcb1106c847.png" width="320">

2 回目の再走の生まれ年ステップ。ホイールは初期値 (現在年 - 39 = 1987) が選択された状態に戻っている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/780cd9c1-bc84-4816-8bca-781add71f64e.png" width="320">

ペイン認識 2 問の回答も残っていない。1 回目 (スヌーズ「ときどき」+ 記憶「いくつかは」) の儀式サマリーは「明日の朝から、始まります。」、2 回目 (スヌーズ「ときどき」+ 記憶「ほとんど覚えていない」) は「明日からの朝は、残っていきます。」と、その回の回答どおりに変わっている (スクショは上の「ペイン認識質問の回答が儀式サマリーに効く」を参照)

</details>

### (文言改定前・回答キー改名前) **オンボーディングのリセットが冪等**: 開発者メニューの「オンボーディングをリセット」で完了フラグとオンボーディング内の回答 (生まれ年・ペイン認識 5 問) が消え、再走すると生まれ年ホイールが初期値に戻る。何度押しても同じ状態になる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** (質問 3 画面の追加後。commit `468ad17`) 開発者メニューの「オンボーディングをリセット」を 5 回実行し、いずれも同じコンセプト画面から再走できた

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/f0e113a0-6923-4998-a277-3f8d85551d9f.png" width="320">

4 回目の再走の生まれ年ステップ。ホイールは初期値 (現在年 - 39 = 1987) が選択された状態に戻っている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/64d51909-156c-4eef-83ae-256dea337174.png" width="320">

増えた 3 問を含めてペイン認識 5 問の回答も残っていない。同じシミュレータで続けて 5 回リセットして別々の回答で通したところ、儀式サマリーの一文はその回の回答どおりに「明日の朝、その「いつか」に答えてください。」→「明日から、あなたの一日は朝に始まります。」→「明日の最初の数分は、スマホではなく問いのために。」→「明日の朝から、始まります。」と変わっており、前の回の回答が残っていない (スクショは上の「ペイン認識質問の回答が儀式サマリーに効く」を参照)

</details>

### **サマリー・ペイウォール表示中の kill で再走する**: アラーム保存後、儀式のサマリーやペイウォールの表示中にアプリを終了して再起動すると、完了扱いでホームへ飛ばず、オンボーディングがコンセプトから再走する。アラーム設定ステップには保存済みの時刻が復元される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** (ローカル simulator mementomorning-sktest-iOS26.2 / iOS 26.2、日本語ロケール、commit `3f084a9`。`xcrun simctl uninstall` → `install` の新規インストール状態から実施)

復元されたことが既定値 7:00 と区別できるよう、アラーム設定ステップでホイールを 9:00 に変えて保存した。儀式のサマリーの 1 行目が「9:00 — アラームが鳴る」になっている。この表示のままアプリを kill する

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/f8563088-97d2-4257-9cf9-2831e5982d23.png" width="320">

`xcrun simctl terminate` で終了させたあとの再起動直後。ホーム (「答えた日数」) ではなくコンセプト「死を想ってから、朝を始める。」から再走している (ホームが出ていないことは maestro の assertNotVisible でも確認)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/0ed60795-2fcf-42cc-b3c7-f511dd958aa9.png" width="320">

そのまま再走してアラーム設定ステップまで進めたところ。ホイールは既定値の 7:00 ではなく、kill 前に保存した 9:00 が復元されている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/48411757-2d23-41de-9834-0a7959c535e3.png" width="320">

比較用に、同じ新規インストールの 1 周目でアラーム設定ステップに初めて来た時のホイール (既定値 7:00)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/865e7fd9-83f9-43da-bad3-b88c8190866a.png" width="320">

修正前は、`@AppStorage` の既定値 false が UserDefaults へ書き込まれないため「完了キーなし + AlarmSetting あり」になり、RootView の旧バージョン移行判定が誤発動してホームへ飛んでいた。commit `3f084a9` で AlarmSetting の保存前に完了キーへ false を明示的に書き込むようにしている

</details>

### **ペイウォールの文脈行**: 儀式のサマリーの「はじめる」(onboarding_summary_begin) でペイウォールが全画面表示され、生まれ年を答えている場合だけ見出し「すべての朝を残すために」の上に夜明け色で「残り約 N 回の朝をすべて残すために」が出る。生まれ年をスキップした場合と、既存の呼び出し (アラーム設定・カレンダー・回答ログ・開発者メニュー) では出ない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** (文言改定後の再確認。ローカル simulator mementomorning-sktest-iOS26.2 / iOS 26.2、日本語ロケール、commit `0832538`。maestro フロー tmp/copyqa-flowA2/B.yaml)

1. 生まれ年 1987 で通した場合。見出し「すべての朝を残すために」の上に夜明け色で「残り約 14,235 回の朝をすべて残すために」が出ている

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/6d2be146-786d-403d-b1bc-9e1272451274.png" width="300" />

2. 生まれ年をスキップした場合。文脈行は出ない (maestro の assertNotVisible でも確認)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/cf997826-9fab-4b0c-8ea8-68a62e049161.png" width="300" />

既存の呼び出し (アラーム設定・カレンダー・回答ログ・開発者メニュー) で出ない分岐は、表示条件のロジックに変更がないため文言改定前の記録が有効 (上の「(文言改定前) ペイウォールの文脈行」を参照)

</details>

### **オンボーディングのリセットが冪等**: 開発者メニューの「オンボーディングをリセット」で完了フラグとオンボーディング内の回答 (生まれ年・ペイン認識 5 問) が消え、再走すると生まれ年ホイールが初期値に戻る。何度押しても同じ状態になる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-27** (回答キー改名 (onboardingWakeAnswer / onboardingMorningSatisfactionAnswer) 後の再確認。commit `0832538`。maestro フロー tmp/copyqa-flowB/C.yaml)

リセット → 再走のサイクルを 2 回 (フロー B・C) 実施し、いずれもコンセプトから再走して生まれ年ホイールが初期値 1987 に戻り、前回の回答が残っていないことを確認 (儀式サマリーの一文がその回の回答どおりに変わる)。リセット操作の実体は完了フラグと回答キーの removeObject のみで、押すたびに同じ削除に収束する

リセット直後の開発者メニューと、再走時の生まれ年ホイール (初期値 1987)

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/30e1a2dc-fe75-40cc-9c14-17492339cea0.png" width="300" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260827/a974fa7a-82c8-4f43-ba0b-d0bb5a286e14.png" width="300" />

</details>

</details>

---
