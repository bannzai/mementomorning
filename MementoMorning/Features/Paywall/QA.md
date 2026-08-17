---
feature: Paywall
verification: mobile-mcp
last_verified_commit: null
last_verified_at: null
---

# Paywall QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/9 (受け入れ条件)
- 関連: https://github.com/bannzai/mementomorning/issues/15 (IAP 商品登録) / https://github.com/bannzai/mementomorning/pull/30 (レビュー指摘の反映)

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | Sandbox で購入 → プレミアム解放 → 復元が確認できる | 購入 / 復元 |
| S2 | 無料状態で無限追撃・全履歴が制限される | — (AlarmSetting の QA.md「無料状態のスヌーズ表示」・AnswerLog の QA.md「無料枠の非表示とロック行」が担当) |

## 1. 表示

- [x] **導線からの表示**: ジャーナルのロック行 (journal_paywall_link) とアラーム設定の「無限追撃アラーム」行 (alarm_setting_endless_alarm_row) のどちらからも sheet で開く
  - 自動化: manual（sheet 遷移の確認）
- [ ] **価格の表示**: offering の取得後、年額 (paywall_yearly_button。ひと月あたり換算付き)・月額 (paywall_monthly_button)・一生 (paywall_lifetime_button) の各プランがストア価格で表示される
  - ⏭️ スキップ: CI ビルドの simulator では RevenueCat が未 configure の可能性が高く、表示された ¥6,000 / ¥800 / ¥9,800 は見本価格と同値のため「offering 取得後のストア価格」であることを画面から判別できない。StoreKit Configuration / Sandbox での課金検証時に確認する
  - 自動化: manual（画面上の価格表示の目視確認。商品定義・判定のロジックは MementoMorningTests/StoreKitConfigurationTests.swift / PremiumEntitlementTests.swift がカバー済み）
- [ ] **年額の無料トライアル表記**: offering の年額に introductory offer (無料トライアル) がある場合、年額ボタン (paywall_yearly_button) の中に期間つきの無料表記 (paywall_yearly_free_trial。例: 1 week free) が表示される。offer が無い・有料の導入価格の場合は表示しない
  - ⏭️ スキップ: RevenueCat が未 configure のローカルビルドでは offering を取得できず、トライアル表記の分岐に到達しない (見本価格の表示に倒れ、トライアル行は出ない。2026-08-17 に画面で確認)。StoreKit Configuration / Sandbox での課金検証時に確認する
  - 自動化: manual（画面上の表記の目視確認。期間の変換ロジックは MementoMorningTests/PaywallSubscriptionPeriodTests.swift、.storekit の offer 定義は MementoMorningTests/StoreKitConfigurationTests.swift がカバー済み）
- [ ] **取得失敗時の再読み込み**: offering の取得に失敗した場合、「料金を再読み込み」(paywall_reload_offering) が表示され、タップで再取得できる
  - 自動化: todo
- [x] **閉じる導線**: 「今はしない」(paywall_not_now_button) で sheet が閉じる
  - 自動化: manual（sheet の dismiss 確認）
- [ ] **法務リンク**: 利用規約・プライバシーポリシーのリンクが開ける
  - 自動化: manual（外部リンクの確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **導線からの表示**: ジャーナルのロック行 (journal_paywall_link) とアラーム設定の「無限追撃アラーム」行 (alarm_setting_endless_alarm_row) のどちらからも sheet で開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/19481930-0328-43c5-b27a-f0c230ad3735.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/9a89ccac-2f8f-4bf4-9bb9-a5d33d644043.jpg" width="320">

(左: アラーム設定の「無限追撃アラーム」行から。右: ジャーナルのロック行から。表示内容は同一)

</details>

### **価格の表示**: offering の取得後、年額 (paywall_yearly_button。ひと月あたり換算付き)・月額 (paywall_monthly_button)・一生 (paywall_lifetime_button) の各プランがストア価格で表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **年額の無料トライアル表記**: offering の年額に introductory offer (無料トライアル) がある場合、年額ボタン (paywall_yearly_button) の中に期間つきの無料表記 (paywall_yearly_free_trial。例: 1 week free) が表示される。offer が無い・有料の導入価格の場合は表示しない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17 (未 configure のローカルビルド。英語ロケール)**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/77b7ed68-5bc1-4345-9b2d-959e4a1e38d3.png" width="320" />

(offering を取得できないため見本価格の表示。トライアル行は出ない = 取得できない時に固定文言を出さない方針どおり)

</details>

### **取得失敗時の再読み込み**: offering の取得に失敗した場合、「料金を再読み込み」(paywall_reload_offering) が表示され、タップで再取得できる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **閉じる導線**: 「今はしない」(paywall_not_now_button) で sheet が閉じる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/a91e72fd-c640-46ff-9e9c-7f18f4b0a5f3.jpg" width="320">

(paywall_not_now_button で閉じた後、後続の画面 (人生カレンダー) へ操作を継続できている)

</details>

### **法務リンク**: 利用規約・プライバシーポリシーのリンクが開ける

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 2. 購入と復元

- [ ] **購入**: Sandbox (または StoreKit Configuration) で購入するとプレミアムが解放され、sheet が閉じてジャーナルの全履歴・スヌーズ無制限が有効になる
  - ⏭️ スキップ: リモート simulator (simtunnel) では Sandbox / StoreKit Configuration の課金操作ができない。ローカルで /ios-storekit-testing により確認する
  - 自動化: manual（Sandbox 課金の操作が必要。/ios-storekit-testing skill を利用できる）
- [ ] **復元**: 「購入を復元」(paywall_restore) で購入済みのプレミアムが復元される
  - ⏭️ スキップ: 同上 (リモート simulator では Sandbox 課金不可)
  - 自動化: manual（Sandbox 課金の操作が必要）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **購入**: Sandbox (または StoreKit Configuration) で購入するとプレミアムが解放され、sheet が閉じてジャーナルの全履歴・スヌーズ無制限が有効になる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **復元**: 「購入を復元」(paywall_restore) で購入済みのプレミアムが復元される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---
