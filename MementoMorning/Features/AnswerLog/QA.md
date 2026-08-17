---
feature: AnswerLog
verification: mobile-mcp
last_verified_commit: null
last_verified_at: null
---

# AnswerLog QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/5 (受け入れ条件)
- 関連: https://github.com/bannzai/mementomorning/issues/9 (全履歴の課金線) / https://github.com/bannzai/mementomorning/issues/7 (共有カード導線)

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 蓄積した回答が日付順に表示される | 回答一覧の表示 |
| S2 | 8 日以上前の回答が無料状態では見えない | 無料枠の非表示とロック行 |

## 1. 一覧表示

- [ ] **空状態**: 回答が 1 件もない状態でジャーナルを開くと「回答は、ひと朝ずつここに集まっていきます」の空状態文言が表示される
  - 自動化: manual（空状態の目視確認。開発者メニューの Delete all answers で再現できる）
- [ ] **回答一覧の表示**: 回答がある状態 (開発者メニューの Seed sample answers で 10 日分投入) で、回答が新しい順に日付 + 本文で一覧表示される。今日の行は日付が「今日」表記で夜明け色になる
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

### **回答一覧の表示**: 回答がある状態 (開発者メニューの Seed sample answers で 10 日分投入) で、回答が新しい順に日付 + 本文で一覧表示される。今日の行は日付が「今日」表記で夜明け色になる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **夜の結果の表示**: 夜の振り返りを記録済みの過去の行の右端に「やれた」(isFulfilled=true) または「—」(false) が表示され、未記録の行には何も出ない

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 2. 無料枠とペイウォール

- [ ] **無料枠の非表示とロック行**: 無料状態では 8 日以上前の回答が一覧に表示されず、末尾にロック行「7日より前の朝は、プレミアムで。」(journal_paywall_link) が表示される
  - 自動化: manual（画面表示の目視確認。閲覧可否判定のロジックは MementoMorningTests/AnswerLogVisibilityTests.swift がカバー済み）
- [ ] **ロック行からペイウォール**: ロック行をタップすると PaywallPage が sheet で開く
  - 自動化: manual（sheet 遷移の確認）
- [ ] **プレミアムの全履歴**: プレミアム状態 (開発者メニューの「Force premium (override)」ON) では 8 日以上前の回答も表示され、ロック行が消える
  - 自動化: manual（課金状態の表示分岐は目視確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **無料枠の非表示とロック行**: 無料状態では 8 日以上前の回答が一覧に表示されず、末尾にロック行「7日より前の朝は、プレミアムで。」(journal_paywall_link) が表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **ロック行からペイウォール**: ロック行をタップすると PaywallPage が sheet で開く

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **プレミアムの全履歴**: プレミアム状態 (開発者メニューの「Force premium (override)」ON) では 8 日以上前の回答も表示され、ロック行が消える

<details><summary>動作確認スクショ</summary>

（未実行）

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
