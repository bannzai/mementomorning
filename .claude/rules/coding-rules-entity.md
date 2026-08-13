---
paths:
  - "MementoMorning/**/*.swift"
---

# コーディングルール（Entity/データ層）

Entity（SwiftData 等）やデータ層に関するコーディングルール。取り込み元: bannzai/Alarmy の同名ルール。
<!-- NOTE: paths はディレクトリ構造が確定後に、Entity ディレクトリ等へ絞ること -->

## ドキュメントコメント

### struct, class, enum には必ずドキュメントコメント（`///`）を追加する

- struct, class, enum の宣言の直前に `///` で始まるドキュメントコメントを記載する
- そのデータ型が何を表し、どのように使用されるかを明確に説明する
- 複雑なエンティティの場合は、使用目的、データ構造、計算ロジックなども記載する

## 命名規則

### 変数名には通常、動詞（editing, selected等）をつけない

- Feature名自体がその役割を表しているため、変数名は名詞のみで良い
- 例: `AnswerEditPage` 内では `editingAnswer` ではなく `answer`
- どうしても必要な場合はコメントで理由を明記する

### AppStorage のkey名と変数名は一致させる

- `UserDefaults+.swift` で定義されたkey名と、`@AppStorage` で使用する変数名を同じにする
- 良い例: `@AppStorage(.lastAnsweredDate) var lastAnsweredDate: Date?`
- 悪い例: `@AppStorage(.lastAnsweredDate) var answeredAt: Date?` （key名と変数名が異なる）
- 理由: key名と変数名が一致していることで、どのUserDefaultsキーを使用しているか一目で分かる

## 文字列とローカライゼーション

### エンティティやデータ層に入れる文字列は翻訳済みのものでなければならない

- SwiftDataモデルなど、永続化されるデータの文字列プロパティには `String(localized:)` を使用する（ユーザーの自由入力値は除く）
- ハードコードされた文字列（`"Morning"` など）を直接入れてはいけない
- Previewのサンプルデータも同様に `String(localized:)` を使用する
- 良い例: `title: String(localized: "Morning")` （`// ja: 朝` コメント付き）
- 悪い例: `title: "Morning"` （ハードコード）
- 理由: アプリの言語設定に関わらず、エンティティに保存されたデータは常に適切な言語で表示される必要があるため

## プロパティ設計

### 保存側で不要な値をnilにする処理は本質的ではない

- enumやフラグで使用するプロパティが変わる場合、保存側で「使わない方をnilにする」処理は不要
- 保存側はそのままの状態で保存し、使用側で enum や flag を switch して適切なプロパティを使用する
- どこまでいっても使用側はプロパティの扱いに注意が必要。保存側で気を遣っても本質的な問題は解決しない
- コメントで使用方法を明記する

### プロパティ更新はドメインメソッド経由で行い、updatedDateTimeを必ず更新する

- SwiftData `@Model` エンティティで外部から更新されるプロパティは `private(set)` にし、ドメインメソッド（セッター）を経由して更新する
- ドメインメソッド内で必ず `updatedDateTime = .now` を更新する
- SwiftDataにはCoreDataの`willSave`のようなモデルレベルのフックが存在しないため、ドメインメソッドで一貫してupdatedDateTimeを更新する運用で対応する
- `updatedDateTime` は `private(set) var updatedDateTime: Date = Date.now` として宣言する
- `onChange(of:)` 等でエンティティの変更を検知する場合は、個別プロパティではなく `updatedDateTime` を監視する

```swift
@Model
final class MorningAnswer {
  private(set) var text: String
  private(set) var updatedDateTime: Date = Date.now

  /// text を更新し、updatedDateTime も同時に更新する
  func setText(text: String) {
    self.text = text
    self.updatedDateTime = .now
  }
}
```

### enum に表示用の文字列やアイコンを返すプロパティは持たせない

- `var label: String` や `var systemImage: String` のような表示ロジックは enum ではなく View に書く
- enum は純粋なデータ型として定義し、表示に関するロジックは使用側（View）で switch 文を使って判定する
