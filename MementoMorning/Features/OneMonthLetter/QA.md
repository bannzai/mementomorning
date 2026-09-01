---
feature: OneMonthLetter
verification: mobile-mcp
last_verified_commit: 5f592ca
last_verified_at: 2026-09-01
---

# OneMonthLetter QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/96

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 回答が 30 件に達すると、30 件から端末内で抽出した頻出語を含む「一ヶ月の手紙」が全画面で表示される | 初回の手紙と頻出語 |
| S2 | 1 通目は無料で表示でき、2 通目以降はプレミアムの場合だけ表示される | 無料状態の制限 / プレミアムの2通目 |
| S3 | 表示済みの手紙は再表示されない | 表示履歴のリセット |
| S4 | DEBUG 開発者メニューから 60 日分の回答投入と表示履歴のリセットができる | 初回の手紙と頻出語 / 表示履歴のリセット |

## 1. 節目の表示

- [x] **初回の手紙と頻出語**: 無料状態で開発者メニューから 60 日分の回答を投入すると、1 通目が全画面で表示され、30 件の回答で最頻出の「family」が示される
  - 自動化: manual（SwiftData の状態作成と全画面表示の目視確認が必要。表示判定と頻出語抽出は MementoMorningTests/OneMonthLetterTests.swift がカバー済み）
- [x] **無料状態の制限**: 1 通目を閉じても、無料状態では回答が 60 件あっても 2 通目が表示されない
  - 自動化: manual（RevenueCat entitlement と表示状態の突き合わせが必要）
- [x] **プレミアムの2通目**: 開発者メニューでプレミアムを強制 ON にすると、未読の2通目が全画面で表示される
  - 自動化: manual（DEBUG のプレミアム上書きと表示状態の突き合わせが必要）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **初回の手紙と頻出語**: 無料状態で開発者メニューから 60 日分の回答を投入すると、1 通目が全画面で表示され、30 件の回答で最頻出の「family」が示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-09-01** (最終レビュー修正後の `5f592ca`、simtunnel、iPhone 17 / iOS 26.5、英語ロケール)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260901/c66a0194-2b1f-492d-9a60-706740fe4496.jpg" width="320" />

(初回表示、無料状態での2通目制限、プレミアム強制 ON 直後の2通目表示、再起動後の再表示防止を再確認した。simtunnel run: https://github.com/bannzai/mementomorning/actions/runs/33460303044)

**確認日: 2026-09-01** (simtunnel、iPhone 17 / iOS 26.5、英語ロケール)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260901/870e6924-9bfe-4c18-afa4-46e3ec4dea5c.jpg" width="320">

(開発者メニューで 60 日分を投入し、「七つの朝」を閉じた直後に `LETTER 1` が全画面表示された。頻出語は端末内抽出結果の `family`)

</details>

### **無料状態の制限**: 1 通目を閉じても、無料状態では回答が 60 件あっても 2 通目が表示されない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-09-01** (simtunnel、iPhone 17 / iOS 26.5、英語ロケール)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260901/d24608f2-cea5-4613-a157-a7ce6a698642.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260901/4f6c7003-df23-41ff-9022-1d7b60a02b60.jpg" width="320">

(回答 60 件・表示済み 1 通・プレミアム判定 false のまま開発者メニューへ戻り、`LETTER 2` が表示されないことを要素ツリーでも確認)

</details>

### **プレミアムの2通目**: 開発者メニューでプレミアムを強制 ON にすると、未読の2通目が全画面で表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-09-01** (simtunnel、iPhone 17 / iOS 26.5、英語ロケール)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260901/356d1b1b-b011-4855-ac47-6bb76b4b369a.jpg" width="320">

(プレミアム強制スイッチを ON にした直後、未読の `LETTER 2` が全画面表示された)

</details>

</details>

---

## 2. 表示履歴

- [x] **表示履歴のリセット**: 表示済みの1通目は再起動後も再表示されず、開発者メニューで表示履歴をリセットすると即座に1通目が再表示される
  - 自動化: manual（再起動と UserDefaults の状態操作が必要）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **表示履歴のリセット**: 表示済みの1通目は再起動後も再表示されず、開発者メニューで表示履歴をリセットすると即座に1通目が再表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-09-01** (simtunnel、iPhone 17 / iOS 26.5、英語ロケール)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260901/e516a8f8-433a-4f05-b763-16a54a9b6a80.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/mementomorning/20260901/494d58f9-55fa-411e-a4fb-a64adb45a1a0.jpg" width="320">

(2 通表示済みでアプリを終了・再起動するとホームが開き、手紙は再表示されなかった。その後、表示履歴をリセットすると即座に `LETTER 1` が再表示された)

</details>

</details>

---
