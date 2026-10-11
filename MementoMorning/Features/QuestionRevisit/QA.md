---
feature: QuestionRevisit
verification: mobile-mcp
last_verified_commit: 6bcca97
last_verified_at: 2026-10-11
---

# QuestionRevisit QA

## 関連リンク

- 仕様: https://github.com/bannzai/mementomorning/issues/187

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 回答が 90 件に達し、未表示かつプレミアムの時だけ、1 件目と 90 件目の回答を左右に並べ「あなたの答えは変わりましたか」と問う全画面が出る | プレミアムで表示 |
| S2 | 無料では回答が 90 件あっても表示されない | 無料では表示しない |
| S3 | 提示順は 7 日 → 30 日 → 90 日で、未読の「七つの朝」「一ヶ月の手紙」を閉じた後に出る | プレミアムで表示 |
| S4 | 表示済みは再表示されず、開発者メニューの「問い直しの表示履歴をリセット」で再表示される | 表示履歴のリセット |
| S5 | 開発者メニューから 90 日分の回答投入と表示履歴のリセットができる (再実行しても壊れない) | プレミアムで表示 / 表示履歴のリセット |

## 1. 節目の表示

- [x] **無料では表示しない**: 無料状態で開発者メニューから 90 日分の回答を投入すると、「七つの朝」と 1 通目の「一ヶ月の手紙」は出るが、閉じた後に `question_revisit_title` は現れない
  - 自動化: manual（RevenueCat entitlement と表示状態の突き合わせが必要。到達判定は MementoMorningTests/QuestionRevisitMilestoneTests.swift がカバー済み）
- [x] **プレミアムで表示**: 開発者メニューでプレミアムを強制 ON にすると、未読の「一ヶ月の手紙」(2・3 通目) を閉じた後に「問い直し」が全画面で表示され、1 件目と 90 件目の回答が左右に並び、問いが 1 行だけ添えられる
  - 自動化: manual（DEBUG のプレミアム上書きと全画面表示の目視確認が必要）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **無料では表示しない**: 無料状態で開発者メニューから 90 日分の回答を投入すると、「七つの朝」と 1 通目の「一ヶ月の手紙」は出るが、閉じた後に `question_revisit_title` は現れない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-10-11** (`6bcca97`、simtunnel、iPhone 17 / iOS 26.5、英語ロケール)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/2026/10/11/8963d0f7-c8ca-48bf-b7d8-7134eafe3300-shot-free-no-revisit.jpg" width="320" />

(無料状態で「問い直し用回答を投入 (90 日分)」をタップすると `seven_mornings_title` → `LETTER 1` の順に出て、`LETTER 1` を閉じると開発者メニューに戻り、要素ツリーに `question_revisit_title` が無いことを確認した。「問い直しの表示済み: false」のまま)

</details>

### **プレミアムで表示**: 開発者メニューでプレミアムを強制 ON にすると、未読の「一ヶ月の手紙」(2・3 通目) を閉じた後に「問い直し」が全画面で表示され、1 件目と 90 件目の回答が左右に並び、問いが 1 行だけ添えられる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-10-11** (`6bcca97`、simtunnel、iPhone 17 / iOS 26.5、英語ロケール)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/2026/10/11/02718b4f-324e-4eb6-bd61-1c19ae6e3b38-shot-revisit-premium.jpg" width="320" />

(プレミアム強制 ON の直後に `LETTER 2` → `LETTER 3` が順に出て、3 通目を閉じた直後に `question_revisit_title` の全画面が出た。左に 1 件目 (Jul 14, 2026「Start building the app I keep dreaming about」)、右に 90 件目 (Oct 11, 2026「Ship my app to the world」) が並び、問い「Has your answer changed?」と閉じるボタンだけで、記号・カウンターは無い。この版では内容が画面の上 1/3 に寄っていたため `4df714f` で中央に寄せた)

ペイウォールの特典に「The 90-day revisit」の行が増えていることも確認した:
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/2026/10/11/5161f7f9-cec7-4989-8ce0-631fa97bca60-shot-paywall.jpg" width="320" />

</details>

</details>

---

## 2. 表示履歴

- [x] **表示履歴のリセット**: 表示済みの「問い直し」は閉じた後に再表示されず、開発者メニューで表示履歴をリセットすると即座に再表示される
  - 自動化: manual（UserDefaults の状態操作が必要）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **表示履歴のリセット**: 表示済みの「問い直し」は閉じた後に再表示されず、開発者メニューで表示履歴をリセットすると即座に再表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-10-11** (`6bcca97`、simtunnel、iPhone 17 / iOS 26.5、英語ロケール)
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/2026/10/11/cd4412b1-bb47-400b-92ef-6a13e504174a-shot-relaunch-home.jpg" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/2026/10/11/2028f02f-09bd-481e-a478-3c9b2ecfe870-shot-reset-reshow.jpg" width="320" />

(閉じた後は開発者メニューに戻り再表示されなかった。アプリを終了・再起動してもホームが開いたまま (1 枚目)。開発者メニューで「問い直しの表示履歴をリセット」をタップすると即座に問い直しが再表示された (2 枚目))

</details>

</details>

---
