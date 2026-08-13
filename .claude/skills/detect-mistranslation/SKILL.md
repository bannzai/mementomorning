---
name: detect-mistranslation
description: 多言語スクリーンショットを比較して翻訳品質をチェックし、問題があれば GitHub Issue を作成する。前提となるスナップショット UI テスト基盤が未整備のため、現状は使用不可 (取り込み元: bannzai/Focus の同名 skill)
---

# Detect Mistranslation

多言語スクリーンショットを比較して翻訳品質をチェックし、問題があれば GitHub Issue を作成する。

## 前提 (未整備)

この skill は多言語スクリーンショットの生成基盤 (SnapshotUITest / `scripts/snapshot_ui_tests/`) を前提とする。本プロジェクトではまだ整備されていないため、**App Store スクリーンショット基盤 (`/appstore-screenshot-builder`) の整備と同時に導入する**。それまでこの skill は実行できない。

整備時は bannzai/Focus (commit 368eb5137fa3f25921a1cfefeeb7aa1231d03fa0) の `.claude/skills/detect-mistranslation/SKILL.md` と `scripts/snapshot_ui_tests/` を本プロジェクトの構成に合わせて取り込み、この SKILL.md を差し替える。

## 実行手順 (整備後)

1. `.claude/rules/localization-guidelines.md` で翻訳ガイドラインを確認する
2. 多言語スクリーンショットを生成する
3. 言語ごとのスクリーンショットを比較し、未翻訳・不自然な翻訳・レイアウト崩れを検出する
4. 問題があれば `Localizable.xcstrings` を修正するか、GitHub Issue を作成する
