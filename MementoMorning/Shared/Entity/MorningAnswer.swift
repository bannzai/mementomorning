import Foundation
import SwiftData

/// 動画回答の文字起こし状態。RawValue だけを SwiftData に保存し、ロケールに依存せず判定する。
enum VideoTranscriptionStatus: String {
    case pending
    case completed
    case failed
}

/// 毎朝の問い「今日死ぬとしたら何をやりたいですか？」へのユーザーの回答。1 日 1 件蓄積され、人生ジャーナルの最小単位になる
@Model
final class MorningAnswer {
    @Attribute(.unique) var id: UUID
    var createdDateTime: Date = Date.now
    private(set) var updatedDateTime: Date = Date.now

    /// 回答が属する日 (その日の 0 時)。同じ日の回答は 1 件に保つ
    private(set) var answeredDate: Date
    /// 回答本文 (ユーザーの自由入力)
    private(set) var text: String
    /// 夜の振り返りの記録。true = やれた / false = やれていない / nil = 未記録。180 日の節目「まだ、やれていないこと」の原資データ
    private(set) var isFulfilled: Bool?
    /// 動画回答で写真ライブラリへ保存した動画の PHAsset localIdentifier。テキスト回答では nil。
    /// 文字起こし (issue #25) が音声トラックの取得に使う。Optional のプリミティブ型のため軽量マイグレーションで追加できる
    private(set) var videoAssetIdentifier: String?
    /// 動画回答の文字起こし状態。nil はこの項目の追加前に保存された動画回答を表す。
    /// Optional のプリミティブ型にして、既存ストアを軽量マイグレーションできるようにする
    private(set) var videoTranscriptionStatusRawValue: String?

    /// 既存の動画回答は文字起こし処理中ではないため failed として扱い、節目の提示を永久に止めない。
    /// テキスト回答には文字起こし状態が無いので nil を返す
    var videoTranscriptionStatus: VideoTranscriptionStatus? {
        guard videoAssetIdentifier != nil else { return nil }
        guard let videoTranscriptionStatusRawValue else { return .failed }
        return VideoTranscriptionStatus(rawValue: videoTranscriptionStatusRawValue) ?? .failed
    }

    // videoAssetIdentifier はテキスト回答の既存呼び出し側では常に nil のため、既定値付きで追加する
    init(id: UUID = .init(), answeredDate: Date, text: String, videoAssetIdentifier: String? = nil) {
        self.id = id
        self.answeredDate = answeredDate
        self.text = text
        self.videoAssetIdentifier = videoAssetIdentifier
        self.videoTranscriptionStatusRawValue = videoAssetIdentifier == nil ? nil : VideoTranscriptionStatus.pending.rawValue
    }

    /// 指定日 (0 時基準) の回答を取得する。1 日 1 件のため 1 件だけ取得する。
    /// 取得の失敗を nil にせず throw するのは、呼び出し側が「取得に失敗した」と「その日は未回答」を区別できるようにするため
    static func answer(day: Date, calendar: Calendar, modelContext: ModelContext) throws -> MorningAnswer? {
        let startOfDay = calendar.startOfDay(for: day)
        var descriptor = FetchDescriptor<MorningAnswer>(predicate: #Predicate { $0.answeredDate == startOfDay })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// text を更新する
    func setText(text: String) {
        self.text = text
        if videoAssetIdentifier != nil {
            self.videoTranscriptionStatusRawValue = VideoTranscriptionStatus.completed.rawValue
        }
        self.updatedDateTime = .now
    }

    /// 動画回答の保存済み動画の localIdentifier を更新する (同じ日に動画で答え直した時は新しい動画で上書きする)。
    /// nil で消去する (動画回答の後にテキストで答え直した時に、古い動画を指し続けないようにする)
    func setVideoAssetIdentifier(videoAssetIdentifier: String?) {
        self.videoAssetIdentifier = videoAssetIdentifier
        self.videoTranscriptionStatusRawValue = videoAssetIdentifier == nil ? nil : VideoTranscriptionStatus.pending.rawValue
        self.updatedDateTime = .now
    }

    /// 同じ動画の文字起こしが失敗したことを記録する。録り直し後の古い処理結果では状態を変えない
    func markVideoTranscriptionFailed(videoAssetIdentifier: String) {
        guard self.videoAssetIdentifier == videoAssetIdentifier,
              videoTranscriptionStatus == .pending
        else {
            return
        }
        self.videoTranscriptionStatusRawValue = VideoTranscriptionStatus.failed.rawValue
        self.updatedDateTime = .now
    }

    /// 夜の振り返りの記録を更新する
    func setFulfilled(isFulfilled: Bool) {
        self.isFulfilled = isFulfilled
        self.updatedDateTime = .now
    }
}

/// 指定日 (0 時基準) の回答を取得する。取得の失敗は未回答と同じ扱い (nil) にする。
/// 失敗と未回答を区別したい呼び出し側は MorningAnswer.answer(day:calendar:modelContext:) を使う
@MainActor
func fetchMorningAnswer(answeredDate: Date, modelContext: ModelContext, calendar: Calendar = .current) -> MorningAnswer? {
    try? MorningAnswer.answer(day: answeredDate, calendar: calendar, modelContext: modelContext)
}
