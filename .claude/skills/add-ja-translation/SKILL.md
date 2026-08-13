---
name: add-ja-translation
description: Text/String(localized:)に// ja:コメントを追記し、Localizable.xcstringsに日本語翻訳を追加
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Add Japanese Translation

このスキルは、SwiftUIコード内の翻訳対象文字列に `// ja:` コメントを追加し、必要に応じて `Localizable.xcstrings` に日本語翻訳エントリーを追加します。

## 使用タイミング

- 新しいUIテキストを追加した時
- `// ja:` コメントが不足している箇所を修正する時
- 翻訳漏れを検出・修正する時

## 実行手順（Progressive Disclosure）

### 1. ガイドラインの確認

まず、翻訳ガイドラインを確認します：

- `.claude/rules/localization-guidelines.md` を参照（対象ファイル操作時に自動ロード）

### 2. 翻訳漏れの検出

以下のスクリプトで翻訳漏れを検出します：

```bash
python scripts/find_missing_ja_translations.py
```

### 3. コメントの追加

`Text()` や `String(localized:)` の上に `// ja:` コメントを追加します。

#### ルール

- `// ja:` コメントは「アプリのUI翻訳が必要な箇所」のみに付ける
- `Text()` や `String(localized:)` の上に書く
- enum ケースの説明コメントやプロパティの説明コメントには `// ja:` を付けない

#### 例

```swift
// ja: 保存
Text("Save")

// ja: 招待コードをシェア
Text("Share Invite Code")
```

### 4. 固有名詞の扱い

アプリ内の固有名詞や機能名が文中に出てくる場合は、必ず `Text()` で埋め込む：

```swift
// ja: 「達成」の使い方
Text("How to use '\(Text("Achievement"))'")
```

### 5. Localizable.xcstrings への追加

`Localizable.xcstrings` に日本語翻訳エントリーを追加します：

```json
"Share Invite Code" : {
  "localizations" : {
    "ja" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "招待コードをシェア"
      }
    }
  }
}
```

**注意**: 日本語（ja）の翻訳のみ追加してください。他言語は後で一括翻訳します。

## チェック項目

- [ ] `// ja:` コメントが適切に追加されているか
- [ ] 固有名詞が `Text()` で埋め込まれているか
- [ ] `Localizable.xcstrings` に日本語エントリーが追加されているか
- [ ] 英文が英語圏の文化やテンションになぞって作成されているか

## 参考ドキュメント

- `.claude/rules/localization-guidelines.md` - 翻訳ガイドライン（対象ファイル操作時に自動ロード）
- `.claude/rules/coding-rules-entity.md` - エンティティに入れる文字列は翻訳済み（対象ファイル操作時に自動ロード）

## 参考スクリプト

- `scripts/find_missing_ja_translations.py` - 日本語翻訳の欠落検出
- `scripts/add_translation_comments.py` - 翻訳コメント追加
