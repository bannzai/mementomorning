---
name: detect-mistranslation
description: 多言語スクリーンショットを比較して翻訳品質をチェックし、問題があれば GitHub Issue を作成する。翻訳追加後の品質チェック、多言語対応の検証、リリース前の翻訳確認で使用する (取り込み元: bannzai/Focus の同名 skill)
---

# Detect Mistranslation

多言語スクリーンショットを比較して翻訳品質をチェックし、問題があれば GitHub Issue を作成する。
スクリーンショット生成の基盤は `MementoMorningSnapshotUITests` ターゲット + `scripts/snapshot_ui_tests/` (詳細は `scripts/snapshot_ui_tests/README.md`)。

## 使用タイミング

- 翻訳追加後の品質チェック
- 多言語対応の検証
- リリース前の翻訳確認

## 実行手順

### 1. ガイドラインの確認

- `.claude/rules/localization-guidelines.md` で翻訳ガイドラインを確認する
- `scripts/snapshot_ui_tests/README.md` でスクリプト群の使い方を確認する

### 2. 多言語スクリーンショットの生成

```bash
./scripts/snapshot_ui_tests/generate_snapshot_ui_test_screenshots.sh
```

- UITest はローカルシミュレータでしか実行できない (リモート simulator では不可。CLAUDE.md「検証方法」のローカル sim フォールバックに該当)
- 対象言語は `MementoMorningSnapshotUITests/Languages.swift` が SSOT (現状 ja / en)
- 出力先: `scripts/snapshot_ui_tests/screenshots/{テストクラス名}/{インデックス}/{言語}.png`

### 3. 翻訳品質チェックの実行

```bash
# Issue 作成まで行う (デフォルト: Codex CLI で分析)
./scripts/snapshot_ui_tests/check_translation_quality.sh

# チェックのみ (Issue 作成なし)
./scripts/snapshot_ui_tests/check_translation_quality.sh --dry-run
```

チェック項目: 文脈に合わない翻訳 / 用語の不統一 / 文字切れ・表示崩れ / 未翻訳 / 機械翻訳の不自然さ

### 4. 結果の確認と対応

問題が検出された場合:

1. スクリプトが GitHub Issue を作成する (Issue へのスクリーンショット添付には Cloudflare R2 の環境変数が必要。`scripts/snapshot_ui_tests/upload_to_r2.sh` のコメント参照)
2. Issue の内容を確認し、`Localizable.xcstrings` を修正する
3. 修正後、再度スクリーンショットを生成してチェックする

## チェックリスト

- [ ] すべての対象言語でスクリーンショットが生成されているか
- [ ] 未翻訳の箇所がないか
- [ ] 翻訳が文脈に合っているか
- [ ] 用語が統一されているか
- [ ] 文字切れ・表示崩れがないか

## 参考ドキュメント

- `.claude/rules/localization-guidelines.md` - 翻訳ガイドライン
- `scripts/snapshot_ui_tests/README.md` - スクリーンショット生成基盤の詳細
- `scripts/find_missing_ja_translations.py` - 日本語翻訳の欠落検出
