import Foundation

extension String {
    /// オンボーディングで入力された生まれ年を保存する UserDefaults キー。
    /// 残りの朝の回数の計算に使う。0 は「未回答 (スキップ)」を表す番兵値
    /// (@AppStorage は Optional<Int> をそのまま扱えず、未回答を nil で表現できない。
    /// 生まれ年として実在しない 0 を未回答に割り当てることで、有効な入力と区別する)
    static let onboardingBirthYear = "onboardingBirthYear"
    /// スヌーズのペイン認識質問への回答を保存する UserDefaults キー。
    /// 値は OnboardingSnoozeAnswer の rawValue。未回答は空文字
    static let onboardingSnoozeAnswer = "onboardingSnoozeAnswer"
    /// 記憶のペイン認識質問への回答を保存する UserDefaults キー。
    /// 値は OnboardingMemoryAnswer の rawValue。未回答は空文字
    static let onboardingMemoryAnswer = "onboardingMemoryAnswer"
}

/// 「朝はスヌーズボタンから始まりますか」への回答
enum OnboardingSnoozeAnswer: String {
    case almostEvery
    case sometimes
    case rarely
}

/// 「先月の朝をいくつ覚えていますか」への回答
enum OnboardingMemoryAnswer: String {
    case almostNone
    case aFew
    case most
}

/// 残りの朝の回数の提示パターン
enum MorningsResultVariant: Equatable {
    /// 生まれ年から回数を数えられた場合。lived はこれまでに迎えた朝、remaining は残りの朝の概算
    case counted(lived: Int, remaining: Int)
    /// 回数を数えられない場合 (生まれ年が未回答・未来の年・平均寿命に達している)
    case unknown
}

/// 残りの朝の回数の計算に使う平均寿命 (年)。
/// US の平均寿命 (CDC 2023: 78.4 歳) を丸めた値。主戦場が US 市場 (documents/PROJECT.md) のため US の値を使う。
/// 画面では「約」として丸めて見せるため、端数や誕生日単位の精密さは要らない
let averageLifeExpectancyYears = 78

/// 生まれ年から、これまでに迎えた朝と残りの朝の回数を求める。
/// 生まれ年が未回答 (0)・未来の年・平均寿命に達している場合は、回数を出さず .unknown を返す
/// (残りが 0 以下になる人に「残り 0 回」と突きつけないため)
func morningsResultVariant(birthYear: Int, currentYear: Int) -> MorningsResultVariant {
    guard birthYear != 0 else { return .unknown }
    let age = currentYear - birthYear
    guard age >= 0, age < averageLifeExpectancyYears else { return .unknown }
    return .counted(lived: age * 365, remaining: (averageLifeExpectancyYears - age) * 365)
}
