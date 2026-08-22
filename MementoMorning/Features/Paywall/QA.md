---
feature: Paywall
verification: mobile-mcp
last_verified_commit: b15c23b53893c3146fd207c21c48e2963f38f8c1
last_verified_at: 2026-08-22
---

# Paywall QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/9 (受け入れ条件)
- 関連: https://github.com/bannzai/mementomorning/issues/15 (IAP 商品登録) / https://github.com/bannzai/mementomorning/pull/30 (レビュー指摘の反映)
- 検証手段: 課金フローは Debug ビルドの既定 (RevenueCat Test Store キー) で simulator (simtunnel 含む) のまま検証できる。手順は AGENTS.md「検証方法」、E2E フローは `.maestro/flows/paywall-teststore.yaml`。導入の経緯は https://github.com/bannzai/mementomorning/issues/51 / https://github.com/bannzai/mementomorning/pull/57

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | Sandbox で購入 → プレミアム解放 → 復元が確認できる | 購入 / 復元 |
| S2 | 無料状態で無限追撃・全履歴が制限される | — (AlarmSetting の QA.md「無料状態のスヌーズ表示」・AnswerLog の QA.md「無料枠の非表示とロック行」が担当) |

## 1. 表示

- [x] **導線からの表示**: ジャーナルのロック行 (journal_paywall_link) とアラーム設定の「無限追撃アラーム」行 (alarm_setting_endless_alarm_row) のどちらからも sheet で開く
  - 自動化: manual（sheet 遷移の確認）
- [x] **価格の表示**: offering の取得後、年額 (paywall_yearly_button。ひと月あたり換算付き)・月額 (paywall_monthly_button)・一生 (paywall_lifetime_button) の各プランがストア価格で表示される
  - 自動化: `.maestro/flows/paywall-teststore.yaml`（Test Store のストア価格は USD のため、見本価格 (¥) と画面上で判別できる。商品定義・判定のロジックは MementoMorningTests/StoreKitConfigurationTests.swift / PremiumEntitlementTests.swift がカバー済み）
- [ ] **年額の無料トライアル表記**: offering の年額に無料トライアルの introductory offer があり、かつそのユーザーが使える (eligible) 場合に、年額ボタン (paywall_yearly_button) の中に期間つきの無料表記 (paywall_yearly_free_trial。例: 1 week free) が表示される。offer が無い・有料の導入価格・トライアル利用済み (ineligible)・判定不能 (unknown) の場合は表示しない
  - ⏭️ スキップ: Test Store の年額商品には introductory offer を設定していないため、Debug ビルドの既定では「offer なし → 表記なし」側しか確認できない (2026-08-17 の Test Store 検証でも表記なしを確認)。eligible 時に表示される側は**実機 QA へ** (Sandbox / StoreKit Configuration の Xcode Run で確認する)
  - 確認範囲 (2026-08-22): StoreKit Configuration の CLI 検証 (`xcodebuild test -only-testing:MementoMorningTests/StoreKitConfigurationTests`、iOS 26.2 simulator) で、`.storekit` の 3 商品の価格・年額のみの 7 日間無料トライアル offer 定義・購入による entitlement 付与までは 2 テスト成功 (exit 0) を確認。残るのは eligible 時の paywall_yearly_free_trial の目視のみ
  - 自動化: manual（画面上の表記の目視確認。期間の変換ロジックは MementoMorningTests/PaywallSubscriptionPeriodTests.swift、.storekit の offer 定義は MementoMorningTests/StoreKitConfigurationTests.swift がカバー済み）
- [ ] **取得失敗時の再読み込み**: offering の取得に失敗した場合、「料金を再読み込み」(paywall_reload_offering) が表示され、タップで再取得できる
  - 自動化: todo
- [x] **閉じる導線**: 「今はしない」(paywall_not_now_button) で sheet が閉じる
  - 自動化: manual（sheet の dismiss 確認）
- [x] **法務リンク**: 利用規約・プライバシーポリシー・特定商取引法に基づく表記 (paywall_specified_commercial_transaction_act_link) のリンクが開ける
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

**確認日: 2026-08-17 (Test Store。Maestro フロー全ステップ COMPLETED)**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/e2509ff3-f355-4ae1-84d8-f7e9bfdb8fb8.png" width="320" />

(年 $38.00 + ひと月 $3.17 換算・月 $5.00・一生 $61.50。Test Store の USD ストア価格で、見本価格 (¥6,000 / ¥800 / ¥9,800) と異なるため offering 取得後の表示であることを画面から判別できる)

</details>

### **年額の無料トライアル表記**: offering の年額に無料トライアルの introductory offer があり、かつそのユーザーが使える (eligible) 場合に、年額ボタン (paywall_yearly_button) の中に期間つきの無料表記 (paywall_yearly_free_trial。例: 1 week free) が表示される。offer が無い・有料の導入価格・トライアル利用済み (ineligible)・判定不能 (unknown) の場合は表示しない

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

### **法務リンク**: 利用規約・プライバシーポリシー・特定商取引法に基づく表記 (paywall_specified_commercial_transaction_act_link) のリンクが開ける

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19 (Maestro でタップ、スクショは xcrun simctl)**

Paywall 下部のリンク行 (購入を復元・利用規約・プライバシーポリシー・特定商取引法に基づく表記):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/bf2cea1a-c111-4755-8dcf-5793fc3edad1.png" width="320" />

特定商取引法に基づく表記リンク → Safari (bannzai.github.io の該当ページ):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/ed9c6a80-b2b0-4a7f-88f3-a7d327fa8ac2.png" width="320" />

(利用規約・プライバシーポリシーのリンク先の URL は LegalLinks へ集約され、設定画面側の 2026-08-19 の確認 (AlarmSetting の QA.md「情報セクション」) と同一 URL のため個別再タップは省略)

</details>

</details>

---

## 2. 購入と復元

- [x] **購入**: 購入するとプレミアムが解放され、sheet が閉じてジャーナルの全履歴・スヌーズ無制限が有効になる (Debug ビルドは Test Store、実ストア相当は Sandbox / StoreKit Configuration)
  - 自動化: `.maestro/flows/paywall-teststore.yaml`（購入 → dismiss → 再起動後も isPremium: true まで検証。解放判定はゲートの判定値 isPremium (開発者メニュー表示) で行い、ジャーナル・スヌーズの画面側は S2 のとおり AlarmSetting / AnswerLog の QA.md が担当）
- [x] **復元**: 「購入を復元」(paywall_restore) で購入済みのプレミアムが復元される
  - 自動化: `.maestro/flows/paywall-teststore.yaml`（購入済み状態で復元 → entitlement が返り dismiss されるまで検証。別端末・再インストール相殺の復元は Test Store では匿名ユーザーが変わるため対象外で、Sandbox での課金検証時に確認する）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **購入**: 購入するとプレミアムが解放され、sheet が閉じてジャーナルの全履歴・スヌーズ無制限が有効になる (Debug ビルドは Test Store、実ストア相当は Sandbox / StoreKit Configuration)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17 (Test Store。Maestro フロー全ステップ COMPLETED)**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/43988669-2064-4b4d-af0a-af8f1922f4ce.png" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/907c6d48-b5e3-4eaa-815c-7413e748bcc5.png" width="320" />

(左: paywall_yearly_button タップで Test Store Purchase モーダルが出て Test valid purchase を選択。右: アプリ再起動後の開発者メニューで isPremium: true。「プレミアムを強制 (上書き)」は OFF なので購入由来の entitlement)

</details>

### **復元**: 「購入を復元」(paywall_restore) で購入済みのプレミアムが復元される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-17 (Test Store。Maestro フロー全ステップ COMPLETED)**
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260817/4f8a0388-8df3-4a51-9514-b435edfcd697.png" width="320" />

(paywall_restore タップで有効な entitlement が返り、paywall が dismiss されて開発者メニューへ戻った直後の画面)

</details>

</details>

---
