---
feature: Onboarding
verification: mobile-mcp
last_verified_commit: null
last_verified_at: null
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
- [ ] **許可拒否時の設定誘導**: アラームまたは通知の許可を拒否すると、設定アプリへの誘導が表示される。設定アプリで許可して戻ると表示が追従する
  - 自動化: manual（画面上の導線の目視確認。誘導要否の判定ロジックは MementoMorningTests/OnboardingPermissionTests.swift がカバー済み）

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

（未実行）

</details>

</details>

---

## 2. 完了

- [x] **完了でホームへ**: アラーム設定ステップ (初期値 7:00) で保存するとオンボーディングが完了し、ホームへフェードで切り替わり、設定した時刻が NEXT MORNING に表示される
  - 自動化: manual（画面遷移と表示の確認）
- [ ] **完了後は再表示しない**: 完了後にアプリを再起動してもオンボーディングは表示されず、ホームから始まる
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

（未実行）

</details>

</details>

---
