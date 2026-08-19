---
feature: AlarmSetting
verification: mobile-mcp
last_verified_commit: 2cff9ff
last_verified_at: 2026-08-19
---

# AlarmSetting QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/3 (受け入れ条件)
- 関連: https://github.com/bannzai/mementomorning/issues/9 (スヌーズ無料枠・無限追撃の課金線)
- 関連: https://github.com/bannzai/mementomorning/issues/73 (スヌーズ回数の Picker 化・アラームトグルの ON 色)

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 設定した時刻にアラームが発火する (発火判定は画面表示で行う) | アラーム発火 |
| S2 | `.claude/rules/ios-alarmkit-constraints.md` の運用ルールに準拠している | — (コードレビューで担保。QA 手動確認の対象外) |
| S3 | ユニットテストが全件パスし CI がグリーン | — (CI で担保。QA 手動確認の対象外) |

## 1. 表示

- [x] **保存済み設定の反映**: 保存済みのアラーム設定がある状態で画面を開くと、時刻 DatePicker とアラームトグルに保存値が反映されている
  - 自動化: manual（Form の表示値はシミュレータ操作と目視でしか確認できない）
- [x] **アラームトグルの ON 色**: アラームトグル (Switch) の ON 状態のトラックがホームの pill トグルと同じ夜明け色 (Color.alarmToggleOn) になり、OFF (灰色) と見分けられる
  - 自動化: manual（色の目視確認）
- [x] **無料状態のスヌーズ Picker**: 無料状態ではスヌーズ行 (accessibilityIdentifier: alarm_setting_snooze_picker) が Picker になり、選択肢は 1〜10 回と「無制限」。3 回以上と「無制限」には錠前アイコンが付き、初期選択は 2 回
  - 自動化: manual（Picker のメニュー表示は目視確認）
- [x] **プレミアム状態のスヌーズ Picker**: プレミアム状態 (開発者メニューの「プレミアムを強制 (上書き)」ON) では錠前が消え、「無制限」に ∞ アイコンが付く。未設定 (保存済み値なし) の初期選択は「無制限」
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

### **アラームトグルの ON 色**: アラームトグル (Switch) の ON 状態のトラックがホームの pill トグルと同じ夜明け色 (Color.alarmToggleOn) になり、OFF (灰色) と見分けられる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

ON:
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/c1d8d697-449b-4d62-bbb9-f9e6d6055369.png" width="320">

OFF:
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/c7afe009-4ce2-4cc6-82d7-c62760782d6b.png" width="320">

</details>

### **無料状態のスヌーズ Picker**: 無料状態ではスヌーズ行 (accessibilityIdentifier: alarm_setting_snooze_picker) が Picker になり、選択肢は 1〜10 回と「無制限」。3 回以上と「無制限」には錠前アイコンが付き、初期選択は 2 回

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/3cdc52e9-599b-4ab9-b8c2-9e4335ffef48.png" width="320">

(1〜10 回 + 無制限。3 回以上と無制限に錠前、2 回にチェック)

</details>

### **プレミアム状態のスヌーズ Picker**: プレミアム状態 (開発者メニューの「プレミアムを強制 (上書き)」ON) では錠前が消え、「無制限」に ∞ アイコンが付く。未設定 (保存済み値なし) の初期選択は「無制限」

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/a723c50b-0b83-4ab0-bda8-311990fcdf2a.png" width="320">

(錠前なし。「∞ 無制限」にチェック)

</details>

</details>

---

## 2. 保存と再スケジュール

- [ ] **時刻の保存**: 時刻を変更して「保存」をタップすると画面が閉じ、ホームの NEXT MORNING の大時刻に反映される
  - 自動化: manual（DatePicker 操作と画面遷移の確認）
- [x] **スヌーズ回数の保存**: Picker で回数を選んで「保存」をタップし、画面を開き直すと選んだ回数が Picker に反映されている (AlarmSetting.snoozeLimit に永続化される)
  - 自動化: manual（Picker 操作と再表示の確認）
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

### **スヌーズ回数の保存**: Picker で回数を選んで「保存」をタップし、画面を開き直すと選んだ回数が Picker に反映されている (AlarmSetting.snoozeLimit に永続化される)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

プレミアム状態で「4 回」を選んで保存 → ホームへ戻る → 設定を開き直すと、Picker の表示が「4 回」(mobile-mcp のアクセシビリティツリーで `alarm_setting_snooze_picker` の label が「スヌーズ、4 回」) のまま保持されていることを確認した (スクショなし。要素ツリーで確認)

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

- [x] **プレミアム限定の回数を選ぶとペイウォール**: 無料状態でスヌーズ Picker の錠前付きの選択肢 (3 回以上・無制限) を選ぶと、選択は元の回数に戻り PaywallPage が sheet で開く
  - 自動化: manual（sheet 遷移の確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **プレミアム限定の回数を選ぶとペイウォール**: 無料状態でスヌーズ Picker の錠前付きの選択肢 (3 回以上・無制限) を選ぶと、選択は元の回数に戻り PaywallPage が sheet で開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/c7f53390-70c5-4a41-aeb8-088b49d9ad94.png" width="320">

(「無制限」を選択 → PaywallPage が開く。「今はしない」で閉じると Picker は「2 回」に戻っている)

</details>

</details>

---
