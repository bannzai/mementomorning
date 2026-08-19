---
feature: AnswerLog
verification: mobile-mcp
last_verified_commit: f07f0fd
last_verified_at: 2026-08-19
---

# AnswerLog QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/5 (受け入れ条件)
- 関連: https://github.com/bannzai/mementomorning/issues/9 (全履歴の課金線) / https://github.com/bannzai/mementomorning/issues/7 (共有カード導線) / https://github.com/bannzai/mementomorning/issues/80 (動画の見返し)

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 蓄積した回答が日付順に表示される | 回答一覧の表示 |
| S2 | 8 日以上前の回答が無料状態では見えない | 無料枠の非表示とロック行 |
| S3 | 動画で答えた朝の動画を見返せる (issue #80) | 動画の見返し |

## 1. 一覧表示

- [ ] **空状態**: 回答が 1 件もない状態でジャーナルを開くと「回答は、ひと朝ずつここに集まっていきます」の空状態文言が表示される
  - 自動化: manual（空状態の目視確認。開発者メニューの Delete all answers で再現できる）
- [x] **回答一覧の表示**: 回答がある状態 (開発者メニューの「Delete all answers」→「Seed sample answers」で 10 日分投入) で、回答が新しい順に日付 + 本文で一覧表示される。今日の行は日付が「今日」表記で夜明け色になる
  - 自動化: manual（並び順・配色の目視確認）
- [ ] **夜の結果の表示**: 夜の振り返りを記録済みの過去の行の右端に「やれた」(isFulfilled=true) または「—」(false) が表示され、未記録の行には何も出ない
  - 自動化: manual（記録状態ごとの表示の目視確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **空状態**: 回答が 1 件もない状態でジャーナルを開くと「回答は、ひと朝ずつここに集まっていきます」の空状態文言が表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **回答一覧の表示**: 回答がある状態 (開発者メニューの「Delete all answers」→「Seed sample answers」で 10 日分投入) で、回答が新しい順に日付 + 本文で一覧表示される。今日の行は日付が「今日」表記で夜明け色になる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/9abf8ebc-c2bd-4dec-95e5-cb33dab12fd4.jpg" width="320">

(Today を先頭に新しい順。Today の日付だけ夜明け色)

</details>

### **夜の結果の表示**: 夜の振り返りを記録済みの過去の行の右端に「やれた」(isFulfilled=true) または「—」(false) が表示され、未記録の行には何も出ない

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 2. 無料枠とペイウォール

- [x] **無料枠の非表示とロック行**: 無料状態では 8 日以上前の回答が一覧に表示されず、末尾にロック行「7日より前の朝は、プレミアムで。」(journal_paywall_link) が表示される
  - 自動化: manual（画面表示の目視確認。閲覧可否判定のロジックは MementoMorningTests/AnswerLogVisibilityTests.swift がカバー済み）
- [x] **ロック行からペイウォール**: ロック行をタップすると PaywallPage が sheet で開く
  - 自動化: manual（sheet 遷移の確認）
- [x] **プレミアムの全履歴**: プレミアム状態 (開発者メニューの「Force premium (override)」ON) では 8 日以上前の回答も表示され、ロック行が消える
  - 自動化: manual（課金状態の表示分岐は目視確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **無料枠の非表示とロック行**: 無料状態では 8 日以上前の回答が一覧に表示されず、末尾にロック行「7日より前の朝は、プレミアムで。」(journal_paywall_link) が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/9abf8ebc-c2bd-4dec-95e5-cb33dab12fd4.jpg" width="320">

(10 件中 Today〜Aug 11 の 7 件のみ表示。Aug 10 以前の 3 件は非表示で、末尾にロック行「Older mornings unlock with Premium. / See every morning」)

</details>

### **ロック行からペイウォール**: ロック行をタップすると PaywallPage が sheet で開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/9a89ccac-2f8f-4bf4-9bb9-a5d33d644043.jpg" width="320">

</details>

### **プレミアムの全履歴**: プレミアム状態 (開発者メニューの「Force premium (override)」ON) では 8 日以上前の回答も表示され、ロック行が消える

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/112ed949-32ca-4956-8f96-b1aa643dafb1.jpg" width="320">

(Aug 10 以前の 3 件を含む 10 件すべてが表示され、ロック行が消えている)

</details>

</details>

---

## 3. 共有カード導線

- [ ] **行タップで共有カード**: 回答行のどこをタップしても AnswerShareCardPage が sheet で開く
  - 自動化: manual（sheet 遷移の確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **行タップで共有カード**: 回答行のどこをタップしても AnswerShareCardPage が sheet で開く

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 4. 動画の見返し

- [x] **動画の見返し**: 動画で答えた回答の行に「動画を見返す」リンク (journal_video_replay_link) が表示され、タップすると再生画面 (answer_video_player) が sheet で開いて保存済みの動画が再生される。テキスト回答の行にはリンクが出ない
  - 自動化: maestro（開発者メニューの「動画回答を疑似再現」ON →「アラーム発火を今すぐ記録」→ 朝の問いで録画開始・停止 → ジャーナル → リンクをタップ、の flow で再現できる）
  - 確認範囲: ローカル simulator (日本語ロケール) で、疑似録画のフィクスチャ動画 (2.6 秒・0x111111 の単色フレーム + 発話音声) を写真ライブラリへ保存した回答行にリンクが出て、タップで再生画面が開き、シークバーが末尾 (0:03 / -0:00) まで進むことを確認した。フィクスチャ動画は単色フレームのため映像の内容自体は目視できない。音声の再生 (playback カテゴリでサイレントスイッチ ON でも鳴ること) は simulator では未検証。写真の権限取り消し時・動画削除時のメッセージ表示は未検証 (判定は MementoMorningTests/AnswerVideoPlayerTests.swift がカバー)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **動画の見返し**: 動画で答えた回答の行に「動画を見返す」リンク (journal_video_replay_link) が表示され、タップすると再生画面 (answer_video_player) が sheet で開いて保存済みの動画が再生される。テキスト回答の行にはリンクが出ない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/546c0d48-3312-4ab0-a316-dff29bcecc93.png" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/a180cbe5-accc-4be5-9a44-74696edd94b7.png" width="320" />

(疑似録画で答えた「今日」の行の本文の下に「動画を見返す」。タップで再生画面が開き、フィクスチャ動画 (単色フレーム) が末尾まで再生された状態。中央タップで標準の再生コントロールが出る)

</details>

</details>

---
