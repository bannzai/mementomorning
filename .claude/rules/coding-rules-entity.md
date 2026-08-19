---
paths:
  - "MementoMorning/**/*.swift"
---

# コーディングルール（Entity/データ層）

Entity（SwiftData 等）やデータ層に関するコーディングルール。取り込み元: bannzai/Alarmy の同名ルール。
<!-- NOTE: paths はディレクトリ構造が確定後に、Entity ディレクトリ等へ絞ること -->

## ドキュメントコメント

- struct, class, enum の宣言直前に `///` のドキュメントコメントを書き、そのデータ型が何を表し、どう使われるかを説明する

## 命名規則

- 変数名には通常、動詞（editing, selected 等）をつけない。Feature 名が役割を表すため名詞だけでよい（`AnswerEditPage` 内では `editingAnswer` ではなく `answer`）。必要な場合はコメントで理由を明記する
- `@AppStorage` の変数名は key 名と一致させる（`@AppStorage(.lastAnsweredDate) var lastAnsweredDate`）。どの UserDefaults キーを使っているか一目で分かるようにするため

## 文字列とローカライゼーション

- SwiftData モデルなど永続化されるデータの文字列プロパティ（Preview のサンプルデータを含む）は `String(localized:)` を使う（ユーザーの自由入力値は除く）。ハードコードした `"Morning"` のような文字列を入れない。エンティティに保存されたデータをアプリの言語設定に関わらず適切な言語で表示するため

## プロパティ設計

- enum やフラグで使うプロパティが変わる場合、保存側で「使わない方を nil にする」処理は不要。そのまま保存し、使用側で enum / flag を switch して適切なプロパティを使う（使用側の注意は結局必要で、保存側で気を遣っても本質的な問題は解決しない）。使用方法はコメントで明記する
- SwiftData `@Model` エンティティで外部から更新されるプロパティは `private(set)` にし、ドメインメソッド（セッター）経由で更新する。ドメインメソッド内で必ず `updatedDateTime = .now` を更新する（SwiftData には CoreData の `willSave` のようなモデルレベルのフックが無いため）。`updatedDateTime` は `private(set) var updatedDateTime: Date = Date.now` として宣言する。実例: `MementoMorning/Shared/Entity/MorningAnswer.swift`
- `onChange(of:)` 等でエンティティの変更を検知する場合は、個別プロパティではなく `updatedDateTime` を監視する
- enum に `var label: String` / `var systemImage: String` のような表示用プロパティを持たせない。enum は純粋なデータ型にし、表示ロジックは使用側（View）の switch で判定する
