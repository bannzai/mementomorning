import Foundation
import NaturalLanguage

/// 回答本文から最も繰り返された意味のある語を抽出する。
///
/// 解析は NaturalLanguage の単語分割だけを使い、回答本文を端末外へ送信しない。
/// 同数の場合は最初に現れた語を返すため、同じ回答列からは常に同じ結果になる。
func mostFrequentMeaningfulWord(in answerTexts: [String]) -> String? {
    var counts: [String: Int] = [:]
    var displayWords: [String: String] = [:]
    var order: [String] = []

    for text in answerTexts {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        if let language = NLLanguageRecognizer.dominantLanguage(for: text) {
            tagger.setLanguage(language, range: text.startIndex..<text.endIndex)
        }
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitPunctuation, .omitWhitespace, .omitOther]
        ) { tag, range in
            let word = String(text[range]).trimmingCharacters(in: tokenTrimCharacters)
            let normalizedWord = normalizeOneMonthLetterWord(word)
            guard !normalizedWord.isEmpty,
                  normalizedWord.rangeOfCharacter(from: .letters) != nil,
                  isMeaningfulLexicalClass(tag),
                  !oneMonthLetterStopWords.contains(normalizedWord)
            else {
                return true
            }

            if counts[normalizedWord] == nil {
                order.append(normalizedWord)
                displayWords[normalizedWord] = word
            }
            counts[normalizedWord, default: 0] += 1
            return true
        }
    }

    guard let highestCount = counts.values.max(),
          let normalizedWord = order.first(where: { counts[$0] == highestCount })
    else {
        return nil
    }
    return displayWords[normalizedWord]
}

private let tokenTrimCharacters = CharacterSet.punctuationCharacters.union(.symbols)

private func normalizeOneMonthLetterWord(_ word: String) -> String {
    word.folding(
        options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
    )
}

/// NaturalLanguage が対応する言語では品詞を使って機能語を除外する。
/// 品詞モデルが語を分類できない場合に備え、英語・日本語の最小リストも併用する。
private let oneMonthLetterFunctionWordTags: Set<NLTag> = [
    .pronoun,
    .determiner,
    .particle,
    .preposition,
    .conjunction,
    .classifier,
]

private func isMeaningfulLexicalClass(_ tag: NLTag?) -> Bool {
    guard let tag else { return true }
    return !oneMonthLetterFunctionWordTags.contains(tag)
}

/// 手紙の主題になりにくい英語の機能語と、日本語の助詞・助動詞。
/// 語彙を推測するリストではなく、頻出語が「the」「を」などになるのを避ける最小限の除外だけを持つ。
private let oneMonthLetterStopWords: Set<String> = [
    "a", "an", "and", "are", "as", "at", "be", "been", "but", "by", "for", "from", "had", "has", "have",
    "he", "her", "hers", "him", "his", "i", "if", "in", "is", "it", "its", "me", "my", "of", "on", "or",
    "our", "ours", "she", "that", "the", "their", "theirs", "them", "they", "this", "to", "was", "we", "were",
    "will", "with", "you", "your", "yours",
    "ある", "いる", "から", "が", "こと", "さ", "し", "する", "た", "だ", "で", "です", "て", "と", "な", "に",
    "の", "は", "へ", "ます", "も", "や", "を",
]
