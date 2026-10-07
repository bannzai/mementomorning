# Custom Product Page (CPP) 設計 plan

`cpp/config.json` の設計根拠を記録する。config.json が SSOT で、本ドキュメントは「なぜその設計にしたか」だけを持つ。

- App: Memento Morning (com.bannzai.MementoMorning) / App ID: 6801673264
- 作成: 2026-10 (castle issue https://github.com/bannzai/castle/issues/1503 「各リポジトリの対応」)
- 適用は `appstore-custom-product-page` skill の `cpp_apply_config.sh --config cpp/config.json`

## 共通方針

- 目的はオーガニック検索流入の拡大。CPP に検索キーワードを割り当て、キーワードごとに検索結果の Creative Asset (search results) と製品ページの header を出し分ける
- 既定の製品ページの訴求 (毎朝、死を想ってから起きるアラーム) は `appstore/creative-assets/default/` (墨の闇に浮かぶ朝日と白紙の冊子。既存の `appstore/product-page-header/` と同じ構図を 16:9 で作り直したもの) で表す
- 世界観の制約 (炎・バッジ・紙吹雪などゲーミフィケーションの記号を使わない静かな世界観。`documents/PROJECT.md`) は Creative Asset にも適用する
- スクリーンショットは新規に作らず、公開中のバージョン (1.0.1) を雛形 (`cpp_create.sh --template-version`) に複製する。CPP 固有の差分は promotionalText・keywords・Creative Asset
- キーワードは公開中バージョンの Keywords の語句だけ割り当てられる。新バージョン承認で割り当てがリセットされるため、承認後に `cpp_apply_config.sh` を再実行して復元する
- 対象 locale は ja と en-US (Keywords が入っている locale)。他の 37 locale はスクリーンショットだけ複製され、header / search results は既定ページのものが出る

## CPP 一覧

### 1. journal-202610 (日記・内省軸)

- 対象オーディエンス: 目覚ましではなく日記・ジャーナル・内省の習慣を探している人
- 流入元: 「日記」「ジャーナル」「内省」「振り返り」「習慣」「朝活」「人生」の検索 (ja)、"journal" "diary" "reflection" "stoic" "mindfulness" "routine" (en-US)
- 仮説: 既定ページは「アラーム」として探す人向け。日記として探す人には、蓄積された回答 (商品はアラームではなくジャーナル。`documents/PROJECT.md`) を主役にした方が一致する。Creative Asset は朝日を外し、白紙の冊子の上に「答えた朝」の点が 7 つ並ぶ構図
- Creative Asset: `appstore/creative-assets/journal/`
- スクリーンショット: 既定ページの複製 (3 枚目「毎朝の答えが、人生の記録になる。」がこの軸の主役だが、順番の入れ替えは効果測定後に検討する)

## 次工程

1. `cpp_create.sh journal-202610 --locale ja --template-version e53a538a-93aa-4213-a3ab-82c17fc8be3c` で作成 (2026-10-07 時点では Apple 側の一時障害 `ENTITY_ERROR.RELATIONSHIP.REQUIRED` で作成できず、再試行中)
2. `cpp_apply_config.sh --config cpp/config.json` で promotionalText と keywords を適用
3. `asset_library_set_placement.sh --target cpp` で header / search results を配置し、ユーザー確認後に `cpp_submit.sh <CPP_ID>` で提出
4. 承認後、App Analytics で CPP ごとの impressions / CVR を計測
