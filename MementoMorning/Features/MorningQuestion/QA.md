---
feature: MorningQuestion
verification: mobile-mcp
last_verified_commit: null
last_verified_at: null
---

# MorningQuestion QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/4 (画面骨格・追撃ループ) / https://github.com/bannzai/mementomorning/issues/24 (動画回答) / https://github.com/bannzai/mementomorning/issues/25 (文字起こし)
- 関連: https://github.com/bannzai/mementomorning/issues/2 (stopIntent 実機検証。シミュレータでは perform() が実行されない既知事象)

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | アラーム停止 → 質問画面 → 回答 → 以降アラームが鳴らない、の一連が通る | 回答成立で全アラームキャンセル |
| S2 | 未回答で放置すると追撃アラームが再度鳴る | 追撃アラーム |
| S3 | 問いオーバーレイ状態でインカメラ録画 → 停止 → 写真アプリに動画が保存される (実機) | 動画回答の録画と保存 |
| S4 | 録画完了で当日の回答が成立し、追撃アラームが止まる | 動画回答の録画と保存 |
| S5 | カメラ/マイク/写真の権限拒否時にテキスト入力へフォールバックする | テキスト入力へのフォールバック |
| S6 | 動画回答の完了後、自動で文字起こしが走り MorningAnswer.text に入る (日本語・英語) | 動画回答の録画と保存 |
| S7 | 文字起こし結果を編集して保存できる | — (AnswerEdit の QA.md「編集して保存」が担当) |
| S8 | オンデバイス認識で動作する (ネットワーク遮断状態で確認) | 動画回答の録画と保存 |

## 1. 提示と解除

- [x] **アラーム発火後の提示**: アラームが発火した朝 (未回答・アラーム ON) にアプリを前面化すると、朝の問いが全画面 (fullScreenCover) で表示され、スワイプでは閉じられない
  - 自動化: manual（発火状態は開発者メニューの「Record alarm fired now」で再現できる。実発火の確認は 1〜2 分後アラームで行う）
  - 確認範囲: 提示は「Record alarm fired now」で確認。スワイプで閉じられないことの操作確認と実発火は未実施
- [ ] **アラーム OFF 中は提示しない**: アラームを OFF にすると、発火記録が残っていても朝の問いが提示されない (提示中でも閉じる)
  - 自動化: manual（画面上の挙動の目視確認。提示判定のロジックは MementoMorningTests/MorningQuestionGateTests.swift がカバー済み）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **アラーム発火後の提示**: アラームが発火した朝 (未回答・アラーム ON) にアプリを前面化すると、朝の問いが全画面 (fullScreenCover) で表示され、スワイプでは閉じられない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/9548a201-9da8-4110-b0db-aba1245ca520.jpg" width="320">

(問いの全画面表示と同時にカメラ許可ダイアログ。説明文の位置に NSCameraUsageDescription のキー名が出ていたのは issue #50 で解消済み)

</details>

### **アラーム OFF 中は提示しない**: アラームを OFF にすると、発火記録が残っていても朝の問いが提示されない (提示中でも閉じる)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 2. テキスト回答

- [x] **テキスト入力へのフォールバック**: カメラ非搭載のシミュレータ (または権限拒否時) では動画回答が使えず、テキスト入力が表示される
  - 自動化: manual（画面上のフォールバックの目視確認。利用可否判定のロジックは MementoMorningTests/VideoAnswerGateTests.swift がカバー済み）
  - 確認範囲: ローカル simulator (英語ロケール) では、動画回答が使えないと判定された時点でテキスト入力へ自動で切り替わり、「The camera isn't available, so answer in text.」が表示されることを確認した。issue #50 で、権限が 1 つでも拒否された時点で残りのリクエストを待たずフォールバックし、セッション起動前は録画ボタンの代わりに「Preparing the camera」を出すよう修正済み
  - 未検証: 「カメラ許可ダイアログで拒否 → その場でフォールバック」の実挙動。ローカル simulator ではカメラ・マイク・写真の許可ダイアログ自体が出ず (カメラ非搭載のため要求が即座に解決する)、修正前のビルドでも同じ画面になり再現できなかった。ダイアログが出る環境 (simtunnel のリモート simulator / 実機) での再確認が必要
- [ ] **昨日の回答の選択式入力**: 昨日の回答がある場合、「昨日の回答を今日やる? YES / NO」の選択式から始まり、断ると自由入力へ切り替わる
  - 自動化: manual（選択式 → 自由入力の切り替え確認）
- [x] **回答の保存**: 自由入力で本文を入れて保存すると画面が閉じ、ホームの「今朝のことば」に反映される
  - 自動化: manual（テキスト入力と反映の確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **テキスト入力へのフォールバック**: カメラ非搭載のシミュレータ (または権限拒否時) では動画回答が使えず、テキスト入力が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/317e94d4-ecb1-4d82-ba1a-743e3d41ad64.jpg" width="320">

**再確認日: 2026-08-17 (issue #50 の修正後。英語ロケール・ローカル simulator)**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/00079cb0-98e9-418d-aeec-34bfaeb7c358.png" width="320" />

(録画ボタンは表示されず、フォールバックの文言とテキスト入力だけになっている)

</details>

### **昨日の回答の選択式入力**: 昨日の回答がある場合、「昨日の回答を今日やる? YES / NO」の選択式から始まり、断ると自由入力へ切り替わる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **回答の保存**: 自由入力で本文を入れて保存すると画面が閉じ、ホームの「今朝のことば」に反映される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/140155d4-0c60-48be-9aba-ac1c73e4b47b.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/b18f13e0-b6f3-432f-8036-29e82705eb7d.jpg" width="320">

(「家族と海を見に行く」を入力 → 保存で全画面が閉じ、ホームの「This morning's words」に反映。フッターの件数が「1 mornings answered」になっていた単数形の不具合は issue #50 で解消済み)

**再確認日: 2026-08-17 (issue #50 の修正後。英語ロケール・ローカル simulator)**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/17ca081d-d3bb-403f-a43b-a3c7f10f2a4d.png" width="320" />

(回答 1 件でフッターが「1 morning answered」)

</details>

</details>

---

## 3. アラーム連携

- [ ] **回答成立で全アラームキャンセル**: 回答が成立すると当日の残アラーム (バックアップ・追撃含む) が全キャンセルされ、以降アラームが鳴らない
  - 自動化: manual（実際に鳴らないことの確認。計画ロジックは MementoMorningTests/ChaseAlarmTests.swift / AlarmPlanEngineTests.swift がカバー済み）
- [ ] **追撃アラーム**: 未回答のまま放置すると追撃アラームが再度発火する (発火判定は画面表示)
  - 自動化: manual（シミュレータでは stopIntent の perform() が実行されない既知事象があるため、発火の実確認は実機。issue #2 参照）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **回答成立で全アラームキャンセル**: 回答が成立すると当日の残アラーム (バックアップ・追撃含む) が全キャンセルされ、以降アラームが鳴らない

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **追撃アラーム**: 未回答のまま放置すると追撃アラームが再度発火する (発火判定は画面表示)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 4. 動画回答 (実機のみ)

- [ ] **動画回答の録画と保存**: 実機で問いがオーバーレイされたインカメラ録画 → 停止すると、写真アプリのアルバムに動画が保存され、文字起こし結果が回答テキストになり (日本語・英語)、追撃アラームが止まる。オンデバイス認識のためネットワーク遮断でも動作する
  - 自動化: manual（カメラ・写真ライブラリ・Speech はシミュレータで動作しないため実機での確認。文字起こしのロジックは MementoMorningTests/VideoAnswerTranscriberTests.swift がカバー）
- [ ] **保存失敗時の再試行**: 動画の保存または回答の確定に失敗した場合、「保存をやり直す」(morning_question_retry_save_button) が表示され、再録画なしで再試行できる
  - 自動化: todo

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **動画回答の録画と保存**: 実機で問いがオーバーレイされたインカメラ録画 → 停止すると、写真アプリのアルバムに動画が保存され、文字起こし結果が回答テキストになり (日本語・英語)、追撃アラームが止まる。オンデバイス認識のためネットワーク遮断でも動作する

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **保存失敗時の再試行**: 動画の保存または回答の確定に失敗した場合、「保存をやり直す」(morning_question_retry_save_button) が表示され、再録画なしで再試行できる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---
