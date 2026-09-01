---
feature: AlarmSetting
verification: mobile-mcp
last_verified_commit: c856c8535623d1d5eef031fe0776555cbab68dce
last_verified_at: 2026-09-01
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
- [x] **スヌーズ間隔 Picker**: スヌーズ行の直下にスヌーズ間隔行 (accessibilityIdentifier: alarm_setting_snooze_interval_picker) が Picker で表示され、選択肢は 1〜10 分の 1 分刻み (課金線なし・全員が選べる)。未設定時の初期選択は 2 分 (issue #135)
  - 自動化: manual（Picker のメニュー表示は目視確認）
- [x] **サウンド Picker**: スヌーズ行の下にサウンド行 (accessibilityIdentifier: alarm_setting_sound_picker) が Picker で表示され、選択肢は Default / Gentle Chime / Morning Bell / Soft Pulse / Silent (ja: デフォルト / やわらかなチャイム / 朝の鐘 / しずかなパルス / 無音)。未設定時の初期選択は Default (issue #133)
  - 自動化: manual（Picker のメニュー表示は目視確認）
- [x] **情報セクション**: 画面末尾の「情報」セクションに利用規約 (alarm_setting_terms_link)・プライバシーポリシー (alarm_setting_privacy_policy_link)・特定商取引法に基づく表記 (alarm_setting_specified_commercial_transaction_act_link)・問い合わせ (alarm_setting_contact_link)・バージョン (alarm_setting_version_row。CFBundleShortVersionString + build) が表示され、https の 3 リンクは Safari で正しいページが開く。問い合わせは mailto (URL の正しさは MementoMorningTests/LegalLinksTests.swift で固定。シミュレータはメール App が無くタップしても遷移しない)
  - 自動化: manual（外部リンクの確認）
- [x] **開発者用のログの導線とログ画面**: スパイクログが設定画面に直接表示されず、情報セクション末尾の「Developer Log」(alarm_setting_developer_log_link) から DeveloperLogPage が開く。ログがある時は本文 (developer_log_text) と「Copy Log」(developer_log_copy_button)・「Clear Log」(developer_log_clear_button) が表示され、Clear Log で「No logs」(developer_log_empty) の空状態になる。ログの作り込みは開発者メニューの「スパイクログにサンプルを設定」(debug_set_sample_spike_log) を使う (issue #103)
  - 自動化: manual（画面遷移と表示の目視確認。コピー結果のペーストボード検証はリモート simulator では手段が無い）

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

### **スヌーズ間隔 Picker**: スヌーズ行の直下にスヌーズ間隔行 (accessibilityIdentifier: alarm_setting_snooze_interval_picker) が Picker で表示され、選択肢は 1〜10 分の 1 分刻み (課金線なし・全員が選べる)。未設定時の初期選択は 2 分 (issue #135)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-26** (simtunnel リモート simulator iPhone 17 / iOS 26.5、英語ロケール)

Snooze の下に Snooze interval 行 (初期選択 2 min):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260826/2848b2ff-c9f4-4767-b136-2549cddb43c1.jpg" width="320" />

Picker を開くと 1 min〜10 min の 10 択で、2 min にチェック (錠前なし = 全選択肢が無料で選べる):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260826/89125dba-2249-4333-a487-35d5524105e9.jpg" width="320" />

</details>

### **サウンド Picker**: スヌーズ行の下にサウンド行 (accessibilityIdentifier: alarm_setting_sound_picker) が Picker で表示され、選択肢は Default / Gentle Chime / Morning Bell / Soft Pulse / Silent (ja: デフォルト / やわらかなチャイム / 朝の鐘 / しずかなパルス / 無音)。未設定時の初期選択は Default (issue #133)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-25** (simtunnel リモート simulator iPhone 17 / iOS 26.5、英語ロケール)

Snooze の下に Sound 行 (初期選択 Default):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260825/46505dc3-2b42-4a8e-92b4-9d133d800741.jpg" width="320" />

Picker を開くと Default / Gentle Chime / Morning Bell / Soft Pulse / Silent の 5 択で、Default にチェック:
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260825/1eba0968-b1ee-416f-8ac4-ca11b6c98de3.jpg" width="320" />

</details>

### **情報セクション**: 画面末尾の「情報」セクションに利用規約 (alarm_setting_terms_link)・プライバシーポリシー (alarm_setting_privacy_policy_link)・特定商取引法に基づく表記 (alarm_setting_specified_commercial_transaction_act_link)・問い合わせ (alarm_setting_contact_link)・バージョン (alarm_setting_version_row。CFBundleShortVersionString + build) が表示され、https の 3 リンクは Safari で正しいページが開く。問い合わせは mailto (URL の正しさは MementoMorningTests/LegalLinksTests.swift で固定。シミュレータはメール App が無くタップしても遷移しない)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19 (Maestro でタップ、スクショは xcrun simctl)**

情報セクションの表示 (バージョン 1.0 (1) を含む):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/9a12332c-a000-4131-9b26-e7962ea29e5f.png" width="320" />

利用規約リンク → Safari (bannzai.github.io。読み込み中):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/ecd1e852-906f-41fe-bcca-29f7f08a0e79.png" width="320" />

プライバシーポリシーリンク → Safari:
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/5f7f4af2-bb49-4940-9abb-d462f224ccb9.png" width="320" />

特定商取引法に基づく表記リンク → Safari:
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/fe2490db-1bbd-4ac1-911c-1ad1def7586e.png" width="320" />

(問い合わせ (mailto) はシミュレータにメール App が無くタップしても遷移しないため、URL の正しさは LegalLinksTests で担保)

</details>

### **開発者用のログの導線とログ画面**: スパイクログが設定画面に直接表示されず、情報セクション末尾の「Developer Log」(alarm_setting_developer_log_link) から DeveloperLogPage が開く。ログがある時は本文 (developer_log_text) と「Copy Log」(developer_log_copy_button)・「Clear Log」(developer_log_clear_button) が表示され、Clear Log で「No logs」(developer_log_empty) の空状態になる。ログの作り込みは開発者メニューの「スパイクログにサンプルを設定」(debug_set_sample_spike_log) を使う (issue #103)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22** (simtunnel リモート simulator iPhone 17 / iOS 26.5、英語ロケール)

設定画面。スパイクログの直表示セクションが無く、情報セクション末尾に「Developer Log」リンクが出ている:
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/d41fa3c6-a618-4702-8a76-105360c9c4b9.jpg" width="320">

開発者メニューの「スパイクログにサンプルを設定」でログを作ってから開いた DeveloperLogPage。ログ本文 (monospace)・Copy Log・Clear Log・問い合わせ時の案内 footer が表示されている。Copy Log をタップしてもクラッシュしない (ペーストボードの中身はリモート simulator では検証手段が無いため未検証):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/4736ac7f-4beb-482c-914e-ab27e1183cb2.jpg" width="320">

Clear Log タップ後の空状態 (「No logs」):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/f89fae9a-3c76-4e81-a94e-ae3aa7472c64.jpg" width="320">

</details>

</details>

---

## 2. 保存と再スケジュール

- [x] **時刻の自動保存**: 設定画面に「保存」ボタンが無く、時刻を変更するとデバウンス (約 0.5 秒) 後に自動保存され、戻るとホームの NEXT MORNING の大時刻に反映される。設定を開き直しても変更後の時刻が復元される (issue #124)
  - 自動化: manual（DatePicker 操作と画面遷移の確認）
  - 実行ナレッジ: 時刻の DatePicker (compact) はタップするとホイールが popover で開く。popover が開いている間は WDA の要素ツリーに `PopoverDismissRegion` しか出ないため座標操作になる。**ホイールはスワイプだと慣性で大きく飛ぶ (100pt のスワイプで 11 行動いた) ので、目的の行を直接タップする**。選択行の 2 行下 / 2 行上をタップすると確実に ±2 動く (iPhone / iOS 26.5 の実測で 1 行 ≒ 32pt。選択行が y≒364、時 の列が x≒213、分 の列が x≒285)。設定後は popover の外をタップして閉じる。**閉じるタップの位置は他の行に当たらない場所にする** (画面下部の余白 (60, 700) は About セクションのリンク行に当たり Safari が開いてしまう。ナビバー直下の余白が安全)
- [x] **スヌーズ回数の自動保存**: Picker で回数を選ぶと自動保存され、画面を開き直すと選んだ回数が Picker に反映されている (AlarmSetting.snoozeLimit に永続化される)
  - 自動化: manual（Picker 操作と再表示の確認）
- [x] **夜リマインド時刻の自動保存**: リマインドの時刻を変更すると自動保存され、画面を開き直すと変更後の時刻が反映されている
  - 自動化: manual（DatePicker 操作と再表示の確認）
- [x] **サウンドの自動保存**: サウンド Picker で別の音を選ぶと自動保存され (AlarmSetting.soundName に永続化)、画面を開き直しても選択が保持されている (issue #133)
  - 自動化: manual（Picker 操作と再表示の確認）
- [x] **スヌーズ間隔の自動保存**: スヌーズ間隔 Picker で別の分数を選ぶと自動保存され (AlarmSetting.snoozeIntervalMinutes に永続化)、画面を開き直しても選択が保持されている (issue #135)
  - 自動化: manual（Picker 操作と再表示の確認）
- [ ] **新規保存**: アラーム未設定 (ホームが --:-- 表示) の状態から値を変更すると、設定が作成されホームに時刻が表示される
  - 自動化: manual（未設定状態はアプリの削除 → 再インストールでしか再現できないため手動）
  - ⏭️ スキップ: ホームが --:-- になる状態 (オンボーディング完了済み + AlarmSetting が 0 件) に到達する手段が無い。OnboardingPage.save() は AlarmSetting を insert して保存できた時だけ hasCompletedOnboarding を true にするため、オンボーディングを抜けた時点で必ず設定が 1 件存在する。開発者メニューの「オンボーディングをリセット」は AlarmSetting を消さず、DebugMenuPage に AlarmSetting を削除する操作も無い (2026-08-22 時点)
- [x] **アラーム発火**: 1〜2 分後の時刻に変更する (自動保存される) と、その時刻にアラームが発火する (発火判定は画面表示。シミュレータは sound .default だと鳴らない)
  - 自動化: manual（発火待ちと画面表示の目視判定が必要）
  - 実行ナレッジ: **AlarmKit のアラート内容はスクリーンショットでは黒い角丸としてしか写らない** (システム側の別レイヤーで描画されるため。`xcrun simctl io screenshot` でも同じ)。発火の判定は WDA のアクセシビリティツリーで行い、アプリ名・問いの本文・停止ボタン (`xmark`) が出ていることを確認する
- [ ] **再スケジュール失敗の表示**: 再スケジュールに失敗した場合はエラーメッセージのアラートが表示される (ホームにも home_reschedule_error が出る)
  - 自動化: todo

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **時刻の自動保存**: 設定画面に「保存」ボタンが無く、時刻を変更するとデバウンス (約 0.5 秒) 後に自動保存され、戻るとホームの NEXT MORNING の大時刻に反映される。設定を開き直しても変更後の時刻が復元される (issue #124)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-24** (simtunnel リモート simulator iPhone 17 / iOS 26.5、英語ロケール。issue #124 の自動保存 UI)

設定画面。ナビゲーションバーに「保存」ボタンが無い (Back とタイトルのみ。WDA 要素ツリーでも Save ボタン 0 件):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260824/6d05b40d-0c8f-420e-abc1-cff21d2ce056.jpg" width="320">

ホイールで 7:00 AM → 8:00 AM に変更 (Time の表示が即 8:00 AM に更新):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260824/2750c305-7bc3-4c8f-880a-b2c270f0a5f8.jpg" width="320">

保存操作なしで Back でホームへ戻ると、NEXT MORNING の大時刻が 8:00 になり「In 10 hr 51 min」に更新されている:
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260824/dd28df3a-99ac-496c-8dc8-6d2098704133.jpg" width="320">

設定を開き直すと Time は 8:00 AM のまま (WDA 要素ツリーで `"value":"8:00 AM"` を確認。SwiftData に永続化されている)

**確認日: 2026-08-22** (iPhone / iOS 26.5 ローカル simulator、日本語ロケール。保存ボタン時代の旧 UI)

保存済みの 7:00 からホイールで 10:26 に変更した直後の設定画面 (「時刻 10:26」):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/c61f8aba-0f59-4ec5-910a-a8fe65932a0e.png" width="320">

「保存」で画面が閉じ、ホームの大時刻が 10:26 になり「あと 0 時間 3 分」に更新されている (端末時刻 10:23):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/e7492a63-3345-4b1e-9a05-bd9f4dceb587.png" width="320">

</details>

### **スヌーズ回数の自動保存**: Picker で回数を選ぶと自動保存され、画面を開き直すと選んだ回数が Picker に反映されている (AlarmSetting.snoozeLimit に永続化される)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-24** (simtunnel リモート simulator iPhone 17 / iOS 26.5、英語ロケール。issue #124 の自動保存 UI)

無料状態で「2 times」→「1 time」を選択 (保存ボタンなし) → ホームへ戻る → 設定を開き直すと Snooze の表示が「1 time」のまま保持されている (WDA 要素ツリーの label「Snooze, 1 time」でも確認):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260824/bd4f6843-d9eb-44e8-93e5-06d85b337c4d.jpg" width="320">

**確認日: 2026-08-19** (保存ボタン時代の旧 UI)

プレミアム状態で「4 回」を選んで保存 → ホームへ戻る → 設定を開き直すと、Picker の表示が「4 回」(mobile-mcp のアクセシビリティツリーで `alarm_setting_snooze_picker` の label が「スヌーズ、4 回」) のまま保持されていることを確認した (スクショなし。要素ツリーで確認)

続けて、開発者メニューで「プレミアムを強制 (上書き)」を OFF にして設定を開くと表示は「2 回」(無料枠の実効値) になり、そのまま保存 → プレミアムを ON に戻して開き直すと「4 回」に戻る (Picker を変更していない保存では保存済みの希望値を上書きしない。PR #78 レビュー対応) ことを確認した

**再確認日: 2026-08-22** (ローカル simulator。プレミアム強制 ON で 4 回を保存 → 開き直して 4 回のまま)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/13d01c14-6bb3-44ff-b5c6-a8829471a970.png" width="320">

</details>

### **夜リマインド時刻の自動保存**: リマインドの時刻を変更すると自動保存され、画面を開き直すと変更後の時刻が反映されている

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-24** (simtunnel リモート simulator iPhone 17 / iOS 26.5、英語ロケール)

Reminder 1 をホイールで 9:00 PM → 10:00 PM に変更 (保存ボタンなし) → ホームへ戻る → 設定を開き直すと 10:00 PM のまま保持されている (WDA 要素ツリーで `"value":"10:00 PM"` も確認):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260824/52e8e247-14a4-4a64-9a12-c1d4ac3ea4bd.jpg" width="320">

</details>

### **サウンドの自動保存**: サウンド Picker で別の音を選ぶと自動保存され (AlarmSetting.soundName に永続化)、画面を開き直しても選択が保持されている (issue #133)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-25** (simtunnel リモート simulator iPhone 17 / iOS 26.5、英語ロケール)

Gentle Chime を選択 (保存ボタンなし) → ホームへ戻る → 設定を開き直すと Sound の表示が Gentle Chime のまま保持されている (WDA 要素ツリーの label「Sound, Gentle Chime」でも確認):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260825/260d81ad-2e6e-4378-8037-d2371cb23506.jpg" width="320" />

Gentle Chime (同梱音源 = AlertSound.named) を選んだ状態で開発者メニューの「テストアラームを 1 分後に登録」を実行すると、登録が成功し (`テストアラーム: 登録済み (発火予定: 2026-08-25T02:06:02Z)`)、1 分後にホーム画面上部へアラームのアラート (黒い角丸 + ✕ 停止ボタン) が発火した。WDA 要素ツリーの発火の判定根拠: `{"type":"Other","label":"MementoMorning, If today were your last day, what would you want to do?, Stop","name":"regular.view"}`。音の聴感はリモート simulator では検証できないため未検証:
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260825/e0683dc1-bb92-47f5-ad2e-0eae70ddbd0c.jpg" width="320" />

</details>

### **スヌーズ間隔の自動保存**: スヌーズ間隔 Picker で別の分数を選ぶと自動保存され (AlarmSetting.snoozeIntervalMinutes に永続化)、画面を開き直しても選択が保持されている (issue #135)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-26** (simtunnel リモート simulator iPhone 17 / iOS 26.5、英語ロケール)

5 min を選択 (保存ボタンなし) → ホームへ戻る → 設定を開き直すと Snooze interval の表示が 5 min のまま保持されている (WDA 要素ツリーの label「Snooze interval, 5 min」でも確認):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260826/a0abb7d1-6dce-4028-99e7-2276b5d788ef.jpg" width="320" />

</details>

### **新規保存**: アラーム未設定 (ホームが --:-- 表示) の状態から値を変更すると、設定が作成されホームに時刻が表示される

<details><summary>動作確認スクショ</summary>

**⏭️ スキップ (2026-08-22)**: --:-- のホームに到達する手段が無いため未実行 (理由はチェック項目の入れ子を参照)。新規インストール直後はオンボーディングが先に出て、そこでアラームが保存される

</details>

### **アラーム発火**: 1〜2 分後の時刻に変更する (自動保存される) と、その時刻にアラームが発火する (発火判定は画面表示。シミュレータは sound .default だと鳴らない)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22** (iPhone / iOS 26.5 ローカル simulator、日本語ロケール)

端末時刻 12:21 に 2 分後の 12:23 で保存した。保存直後のホームは大時刻が 12:23、その下が「あと 0 時間 2 分」、アラームのトグルはオン:

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/27756b12-f9bf-4e2e-9152-8f35b85e20b3.png" width="320">

アプリをバックグラウンド (ホーム画面) にして待機し、12:23 に画面上部へアラームのアラートが出た (下のスクショの黒い角丸がアラート本体。AlarmKit のアラート内容はシステム側の別レイヤーで描画されるためスクリーンショットには写らず、右の ✕ = 停止ボタンだけが写る):

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260822/e75c9f35-6e87-405d-9a7b-5eb7ced8858b.png" width="320">

同じ瞬間 (12:23:15 取得) のアクセシビリティツリー (発火の判定根拠):

```json
{"type":"StaticText","label":"MementoMorning"}
{"type":"StaticText","label":"今日死ぬとしたら何をやりたいですか？"}
{"type":"Button","label":"停止","identifier":"xmark"}
```

</details>

### **再スケジュール失敗の表示**: 再スケジュールに失敗した場合はエラーメッセージのアラートが表示される (ホームにも home_reschedule_error が出る)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 3. ペイウォール導線

- [x] **プレミアム限定の回数を選ぶとペイウォール**: 無料状態でスヌーズ Picker の錠前付きの選択肢 (3 回以上・無制限) を選ぶと、選択は元の回数に戻り PaywallPage が sheet で開く。巻き戻った選択は自動保存されない (開き直しても元の回数のまま)
  - 自動化: manual（sheet 遷移の確認）
- [x] **プレミアム行の恒常導線**: 無料状態では夜のリマインドセクションと情報セクションの間に「プレミアム」行 (alarm_setting_premium_link。説明文「無限追撃アラームと、すべての履歴」付き) が表示され、タップすると PaywallPage が sheet で開く (issue #104)
  - 自動化: manual（sheet 遷移の確認）
- [x] **プレミアム状態の表示切り替え**: プレミアム状態 (開発者メニューの「プレミアムを強制 (上書き)」ON) では、プレミアム行は「プレミアム 有効」(alarm_setting_premium_status_row) の状態表示になってペイウォールを開かない (issue #104)
  - 自動化: manual（課金状態の表示分岐は目視確認）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **プレミアム限定の回数を選ぶとペイウォール**: 無料状態でスヌーズ Picker の錠前付きの選択肢 (3 回以上・無制限) を選ぶと、選択は元の回数に戻り PaywallPage が sheet で開く。巻き戻った選択は自動保存されない (開き直しても元の回数のまま)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-24** (simtunnel リモート simulator iPhone 17 / iOS 26.5、英語ロケール。issue #124 の自動保存 UI)

無料状態 (Snooze 1 time) で「Unlimited」(錠前付き) を選択 → PaywallPage が sheet で開く:
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260824/8174d458-41f2-44bd-b69b-cdc28f9cbffe.jpg" width="320">

「Not now」で閉じると Picker は「1 time」に戻っている (WDA 要素ツリーの label「Snooze, 1 time」でも確認。巻き戻りは自動保存されず、開き直しても 1 time のまま):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260824/3c3a8e87-5774-4472-99e1-e8250b62ec33.jpg" width="320">

**確認日: 2026-08-19** (保存ボタン時代の旧 UI)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260819/c7f53390-70c5-4a41-aeb8-088b49d9ad94.png" width="320">

(「無制限」を選択 → PaywallPage が開く。「今はしない」で閉じると Picker は「2 回」に戻っている)

</details>

### **プレミアム行の恒常導線**: 無料状態では夜のリマインドセクションと情報セクションの間に「プレミアム」行 (alarm_setting_premium_link。説明文「無限追撃アラームと、すべての履歴」付き) が表示され、タップすると PaywallPage が sheet で開く (issue #104)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23** (iPhone / iOS 26.5 ローカル simulator、日本語ロケール。issue #94 の夜リマインド時刻編集とのマージ後 UI)

無料状態の設定画面。夜のリマインドセクションの下に「プレミアム」行:
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260823/a43b711a-b0f5-43ee-a695-5d88b9c52461.png" width="320">

「プレミアム」行をタップ → PaywallPage が sheet で開く (価格は RevenueCat Test Store の USD 表示):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260823/eaf81abc-4cd9-4d5a-b2eb-cfa42a9c7692.png" width="320">

</details>

### **プレミアム状態の表示切り替え**: プレミアム状態 (開発者メニューの「プレミアムを強制 (上書き)」ON) では、プレミアム行は「プレミアム 有効」(alarm_setting_premium_status_row) の状態表示になってペイウォールを開かない (issue #104)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23** (iPhone / iOS 26.5 ローカル simulator、日本語ロケール)

プレミアム強制 ON の設定画面。「プレミアム 有効」の状態表示 (夜のリマインドの追加ボタンの錠前も消えている = issue #94 側の分岐):
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260823/ddc20822-f76f-4637-bb2b-2785d3778c65.png" width="320">

</details>

</details>

---
