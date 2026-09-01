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
        let language = NLLanguageRecognizer.dominantLanguage(for: text)
        if let language {
            tagger.setLanguage(language, range: text.startIndex..<text.endIndex)
        }
        let stopWords = oneMonthLetterStopWords(for: language)
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
                  !stopWords.contains(normalizedWord)
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

    guard let highestCount = counts.values.max(), highestCount >= 2,
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
/// 品詞モデルが語を分類できない場合に備え、対応言語ごとの最小リストも併用する。
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

/// 端末に品詞モデルが無い場合のフォールバック。
/// プロジェクトの対応言語ごとに、主題にならない最小限の機能語だけを持つ。
private let oneMonthLetterStopWordsByLanguage: [String: Set<String>] = [
    "ar": ["و", "او", "في", "من", "على", "الى", "عن", "ان", "ما", "لا", "هذا", "هذه", "هو", "هي", "انا", "نحن", "انت", "كان", "مع"],
    "ca": ["el", "la", "els", "les", "un", "una", "i", "o", "de", "del", "a", "en", "per", "amb", "que", "es"],
    "cs": ["a", "i", "ale", "nebo", "ze", "se", "si", "v", "ve", "na", "do", "z", "s", "pro", "je", "jsou"],
    "da": ["og", "i", "at", "det", "en", "et", "er", "som", "pa", "af", "til", "med", "for", "ikke"],
    "de": ["der", "die", "das", "ein", "eine", "und", "oder", "zu", "von", "mit", "auf", "in", "ist", "sind", "ich", "du", "er", "sie", "es", "wir"],
    "el": ["και", "η", "το", "τα", "ο", "οι", "ενα", "μια", "σε", "απο", "με", "για", "που", "ειναι"],
    "en": ["a", "an", "and", "are", "as", "at", "be", "been", "but", "by", "for", "from", "had", "has", "have", "he", "her", "hers", "him", "his", "i", "if", "in", "is", "it", "its", "me", "my", "of", "on", "or", "our", "ours", "she", "that", "the", "their", "theirs", "them", "they", "this", "to", "was", "we", "were", "will", "with", "you", "your", "yours"],
    "es": ["el", "la", "los", "las", "un", "una", "unos", "unas", "y", "o", "de", "del", "a", "en", "por", "para", "con", "que", "es", "son"],
    "fi": ["ja", "tai", "etta", "se", "ne", "yksi", "on", "ovat", "tama", "tuo", "mina", "sina", "me", "te", "he", "kanssa"],
    "fr": ["le", "la", "les", "un", "une", "des", "et", "ou", "de", "du", "a", "en", "pour", "avec", "que", "est", "sont"],
    "he": ["ו", "או", "ה", "של", "את", "על", "אל", "ב", "עם", "כי", "זה", "זאת", "הוא", "היא", "אני", "אנחנו"],
    "hi": ["और", "या", "का", "की", "के", "को", "में", "से", "पर", "है", "हैं", "एक", "यह", "वह", "मैं", "हम"],
    "hr": ["i", "ili", "da", "je", "su", "u", "na", "od", "za", "s", "se", "jedan", "jedna"],
    "hu": ["es", "vagy", "hogy", "a", "az", "egy", "van", "vannak", "ban", "ben", "nak", "nek"],
    "id": ["dan", "atau", "yang", "di", "ke", "dari", "untuk", "dengan", "adalah", "ini", "itu", "saya", "kamu"],
    "it": ["il", "lo", "la", "i", "gli", "le", "un", "una", "e", "o", "di", "del", "a", "in", "per", "con", "che", "e", "sono"],
    "ja": ["ある", "いる", "から", "が", "こと", "さ", "し", "する", "た", "だ", "で", "です", "て", "と", "な", "に", "の", "は", "へ", "ます", "も", "や", "を"],
    "ko": ["은", "는", "이", "가", "을", "를", "에", "에서", "와", "과", "하고", "의", "도", "로", "으로", "있다", "하다"],
    "ms": ["dan", "atau", "yang", "di", "ke", "dari", "untuk", "dengan", "adalah", "ini", "itu", "saya", "anda"],
    "nb": ["og", "i", "at", "det", "en", "et", "er", "som", "pa", "av", "til", "med", "for", "ikke"],
    "no": ["og", "i", "at", "det", "en", "et", "er", "som", "pa", "av", "til", "med", "for", "ikke"],
    "nl": ["de", "het", "een", "en", "of", "van", "in", "op", "voor", "met", "dat", "is", "zijn"],
    "pl": ["i", "lub", "ze", "sie", "w", "na", "z", "do", "od", "dla", "jest", "sa", "ten", "ta", "to"],
    "pt": ["o", "a", "os", "as", "um", "uma", "e", "ou", "de", "do", "da", "em", "no", "na", "por", "para", "com", "que", "e", "sao"],
    "ro": ["si", "sau", "ca", "se", "in", "pe", "de", "la", "cu", "pentru", "este", "sunt", "un", "o"],
    "ru": ["и", "или", "что", "в", "на", "с", "из", "к", "от", "для", "это", "он", "она", "я", "мы", "вы", "есть", "быть"],
    "sk": ["a", "i", "ale", "alebo", "ze", "sa", "si", "v", "na", "do", "z", "s", "pre", "je", "su", "ten", "ta", "to"],
    "sv": ["och", "i", "att", "det", "en", "ett", "ar", "som", "pa", "av", "till", "med", "for", "inte"],
    "th": ["และ", "หรือ", "ที่", "ใน", "ของ", "เป็น", "มี", "ไป", "มา", "กับ", "จาก", "นี้", "นั้น", "ฉัน", "เรา"],
    "tr": ["ve", "veya", "bir", "bu", "su", "o", "ile", "icin", "de", "da", "den", "dan", "mi", "dir"],
    "uk": ["і", "або", "що", "в", "на", "з", "із", "до", "від", "для", "це", "він", "вона", "я", "ми", "ви", "є", "бути"],
    "vi": ["va", "hoac", "la", "cua", "o", "trong", "den", "tu", "cho", "voi", "mot", "nay", "do", "toi", "ban"],
    "zh": ["的", "了", "和", "是", "在", "有", "我", "你", "他", "她", "它", "我们", "你们", "他们", "这", "那", "一个", "与", "或", "从", "到", "为", "对"],
]

private func oneMonthLetterStopWords(for language: NLLanguage?) -> Set<String> {
    guard let language else { return [] }
    let languageCode = language.rawValue.split(separator: "-").first.map(String.init) ?? language.rawValue
    return oneMonthLetterStopWordsByLanguage[languageCode] ?? []
}
