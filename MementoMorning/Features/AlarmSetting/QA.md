---
feature: AlarmSetting
verification: mobile-mcp
last_verified_commit: null
last_verified_at: null
---

# AlarmSetting QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/3 (受け入れ条件)
- 関連: https://github.com/bannzai/mementomorning/issues/9 (スヌーズ無料枠・無限追撃の課金線)

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 設定した時刻にアラームが発火する (発火判定は画面表示で行う) | アラーム発火 |
| S2 | `.claude/rules/ios-alarmkit-constraints.md` の運用ルールに準拠している | — (コードレビューで担保。QA 手動確認の対象外) |
| S3 | ユニットテストが全件パスし CI がグリーン | — (CI で担保。QA 手動確認の対象外) |

## 1. 表示

- [x] **保存済み設定の反映**: 保存済みのアラーム設定がある状態で画面を開くと、時刻 DatePicker とアラームトグルに保存値が反映されている
  - 自動化: manual（Form の表示値はシミュレータ操作と目視でしか確認できない）
- [x] **無料状態のスヌーズ表示**: 無料状態ではスヌーズ行に「〜回まで (無料)」と表示され、「無限追撃アラーム」行 (accessibilityIdentifier: alarm_setting_endless_alarm_row) が表示される
  - 自動化: manual（課金状態の表示分岐は目視確認）
- [x] **プレミアム状態のスヌーズ表示**: プレミアム状態 (開発者メニューの「Force premium (override)」ON) ではスヌーズ行が「無制限」になり、「無限追撃アラーム」行が消える
  - 自動化: manual（課金状態の表示分岐は目視確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **保存済み設定の反映**: 保存済みのアラーム設定がある状態で画面を開くと、時刻 DatePicker とアラームトグルに保存値が反映されている

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/9d1547c7-b90e-43bc-9880-a60339b23513.jpg" width="320">

(オンボーディングで保存した 7:00 / トグル ON が反映されている)

</details>

### **無料状態のスヌーズ表示**: 無料状態ではスヌーズ行に「〜回まで (無料)」と表示され、「無限追撃アラーム」行 (accessibilityIdentifier: alarm_setting_endless_alarm_row) が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/9d1547c7-b90e-43bc-9880-a60339b23513.jpg" width="320">

(Snooze「Up to 2 times (free)」と「Endless follow-up alarm / Premium」行)

</details>

### **プレミアム状態のスヌーズ表示**: プレミアム状態 (開発者メニューの「Force premium (override)」ON) ではスヌーズ行が「無制限」になり、「無限追撃アラーム」行が消える

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/fc05a8ba-b55d-425b-a828-1a97bc0b0485.jpg" width="320">

(Snooze「Unlimited」になり「Endless follow-up alarm」行が消えている)

</details>

</details>

---

## 2. 保存と再スケジュール

- [ ] **時刻の保存**: 時刻を変更して「保存」をタップすると画面が閉じ、ホームの NEXT MORNING の大時刻に反映される
  - 自動化: manual（DatePicker 操作と画面遷移の確認）
- [ ] **新規保存**: アラーム未設定 (ホームが --:-- 表示) の状態から保存すると、設定が作成されホームに時刻が表示される
  - 自動化: manual（未設定状態はアプリの削除 → 再インストールでしか再現できないため手動）
- [ ] **アラーム発火**: 1〜2 分後の時刻で保存すると、その時刻にアラームが発火する (発火判定は画面表示。シミュレータは sound .default だと鳴らない)
  - 自動化: manual（発火待ちと画面表示の目視判定が必要）
- [ ] **再スケジュール失敗の表示**: 再スケジュールに失敗した場合は画面が閉じず、エラーメッセージが表示される (ホームにも home_reschedule_error が出る)
  - 自動化: todo

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **時刻の保存**: 時刻を変更して「保存」をタップすると画面が閉じ、ホームの NEXT MORNING の大時刻に反映される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **新規保存**: アラーム未設定 (ホームが --:-- 表示) の状態から保存すると、設定が作成されホームに時刻が表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **アラーム発火**: 1〜2 分後の時刻で保存すると、その時刻にアラームが発火する (発火判定は画面表示。シミュレータは sound .default だと鳴らない)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **再スケジュール失敗の表示**: 再スケジュールに失敗した場合は画面が閉じず、エラーメッセージが表示される (ホームにも home_reschedule_error が出る)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 3. ペイウォール導線

- [x] **無限追撃アラーム行からペイウォール**: 無料状態で「無限追撃アラーム」行をタップすると PaywallPage が sheet で開く
  - 自動化: manual（sheet 遷移の確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **無限追撃アラーム行からペイウォール**: 無料状態で「無限追撃アラーム」行をタップすると PaywallPage が sheet で開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/19481930-0328-43c5-b27a-f0c230ad3735.jpg" width="320">

</details>

</details>

---
