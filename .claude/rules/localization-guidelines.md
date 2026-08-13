---
paths:
  - "MementoMorning/**/*.swift"
  - "MementoMorning/Localizable.xcstrings"
---

# ローカライゼーションガイドライン

このドキュメントは、Memento Morning プロジェクトの翻訳（ローカライゼーション）に関するガイドラインを定義します。

## 基本情報

- アプリの基本言語は**英語**
- コード上のコメントは**日本語**（メインの開発者が日本人だから）
- `.xcstrings` の方式を採用しています。ファイル名は `Localizable.xcstrings` です
- **Localizable.xcstrings は指示がない限り編集しないでください**
- 翻訳対象言語は**30種類以上**です

## 基本ルール

- TextなどのSwiftUI標準のローカライズ対象になるものや、`String(localized:)` に書く文字列は**英文で書いてください**。英語圏ユーザーにはそのまま表示されます
- 英文は英語圏の文化やテンションになぞって作成してください
- **コードを書くときは `Text("English sentence")` の上に `// ja:` から始まるコメントで日本語訳を書いてください**

## `// ja:` コメントの書き方

### いつ使うか

- `// ja:` コメントは「**アプリのUI翻訳が必要な箇所**」のみに付ける
- `Text()` や `String(localized:)` の上に書く
- enum ケースの説明コメントやプロパティの説明コメントには `// ja:` を付けない（これらは翻訳対象ではない）

### 書き方の例

```swift
// ja: 保存
Text("Save")
```

### 改行の扱い

- 改行は`\n`ではなく、空行としてコメントに残して

## 固有名詞と機能名の扱い

### アプリ内の固有名詞や機能名が文中に出てくる場合は、必ずText()で埋め込む

- 固有名詞: Achievement, App Restriction Group, Schedule, Quick Block, Location Block など
- 機能名: Sync data, Templates, Calculation Methods など

良い例:
```swift
// ja: 「達成」の使い方
Text("How to use '\(Text("Achievement"))'")

// ja: 「データを同期」を押してください
Text("You should press '\(Text("Sync data"))'")
```

悪い例:
```swift
// ❌ 固有名詞が直接文字列に含まれている
Text("How to use 'Achievement'")
Text("You should press 'Sync data'")
```

理由: 固有名詞も多言語対応の対象であり、Localizable.xcstringsで一元管理するため

### 引用符の使用

- 固有名詞は引用符で囲んでください
- 英語であればシングルクォート（`''`）
- 日本語であれば（`「」`）

## 翻訳の追加方法

1. SwiftUIのコード内で `String(localized:)` または `Text()` で英語の文言を記述
2. アプリの翻訳が必要な箇所はコメントで日本語訳を記載（例: `// ja: 招待コードをシェア`）。アプリの翻訳以外のコメントは `ja:` 無しで（例: `// コメント`）
3. `Localizable.xcstrings` に該当の英語文言のエントリーを追加し、jaのlocalizationのみを追加

### 例

```swift
// ja: 招待コードをシェア
Text("Share Invite Code")
```

Localizable.xcstrings への追加:
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

## 注意事項

- コーディング段階では**日本語（ja）の翻訳のみ追加**してください
- 他の言語（ar, ca, cs, de, el, es, fi, fr, he, hi, hr, hu, id, it, ko, ms, nb, nl, pl, pt, ro, ru, sk, sv, th, tr, uk, vi, zh等）は追加しないでください
- 後で翻訳AIのAPIを使用して、英語原文と日本語訳を参考に他言語への翻訳を一括で行うため、この段階では日本語のみで十分です
- Twitter, Instagramなどにシェアする文言のハッシュタグは1つにします。

## 全言語への一括翻訳

日本語訳を元にした全言語への一括翻訳・欠落検査・品質レビューは `/translate-app-xcstrings` skill で行う（プロジェクト固有の翻訳スクリプトは新設しない）。

## 関連スクリプト

- `scripts/find_missing_ja_translations.py` - 日本語翻訳の欠落検出
- `scripts/add_translation_comments.py` - 翻訳コメント追加
