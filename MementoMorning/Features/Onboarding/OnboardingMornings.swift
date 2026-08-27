import Foundation

extension String {
    /// オンボーディングで入力された生まれ年を保存する UserDefaults キー。
    /// 残りの朝の回数の計算に使う。0 は「未回答 (スキップ)」を表す番兵値
    /// (@AppStorage は Optional<Int> をそのまま扱えず、未回答を nil で表現できない。
    /// 生まれ年として実在しない 0 を未回答に割り当てることで、有効な入力と区別する)
    static let onboardingBirthYear = "onboardingBirthYear"
    /// 起床のペイン認識質問への回答を保存する UserDefaults キー。
    /// 値は OnboardingWakeAnswer の rawValue。未回答は空文字
    static let onboardingWakeAnswer = "onboardingWakeAnswer"
    /// 朝の迎え方への満足度の質問への回答を保存する UserDefaults キー。
    /// 値は OnboardingMorningSatisfactionAnswer の rawValue。未回答は空文字
    static let onboardingMorningSatisfactionAnswer = "onboardingMorningSatisfactionAnswer"
    /// 目覚めてすぐの過ごし方の質問への回答を保存する UserDefaults キー。
    /// 値は OnboardingFirstMinutesAnswer の rawValue。未回答は空文字
    static let onboardingFirstMinutesAnswer = "onboardingFirstMinutesAnswer"
    /// 一日が本当に始まる時間帯の質問への回答を保存する UserDefaults キー。
    /// 値は OnboardingDayBeginAnswer の rawValue。未回答は空文字
    static let onboardingDayBeginAnswer = "onboardingDayBeginAnswer"
    /// 「いつかやる」と言い続けていることの質問への回答を保存する UserDefaults キー。
    /// 値は OnboardingUndoneGoalAnswer の rawValue。未回答は空文字
    static let onboardingUndoneGoalAnswer = "onboardingUndoneGoalAnswer"
}

/// 「朝は一度のアラームで起きられますか」への回答
enum OnboardingWakeAnswer: String {
    case almostNever
    case sometimes
    case almostAlways
}

/// 「いまの朝の迎え方に満足していますか」への回答
enum OnboardingMorningSatisfactionAnswer: String {
    case notReally
    case somewhat
    case mostly
}

/// 「目覚めてすぐの時間をどう過ごしていますか」への回答
enum OnboardingFirstMinutesAnswer: String {
    case scrolling
    case rushing
    case ritual
}

/// 「あなたの一日はいつ本当に始まりますか」への回答
enum OnboardingDayBeginAnswer: String {
    case morning
    case noon
    case evening
}

/// 「『いつかやる』と言い続けていることはありますか」への回答
enum OnboardingUndoneGoalAnswer: String {
    case undone
    case aFew
    case notReally
}

/// 儀式のサマリーに出すパーソナライズの一文
enum RitualSummaryNote {
    /// 手つかずの「いつか」に明日の朝答えるよう促す
    case answerSomeday
    /// スヌーズが要らなくなることを伝える
    case noMoreSnoozing
    /// 明日から胸を張れる朝になることを伝える
    case proudMornings
    /// 一日が朝から始まるようになることを伝える
    case dayBeginsMorning
    /// 最初の数分がスマホではなく問いに向かうことを伝える
    case firstMinutesToQuestion
    /// 特定のペインに紐づかない場合の既定の一文
    case startsTomorrow
}

/// ペイン認識質問の回答から、儀式のサマリーに出す一文を 1 つ選ぶ。
/// 優先順は「目的 (手つかずの『いつか』) > アラームのメカニクス (起床) > 朝の迎え方への満足 > 一日の始まる時間帯 > スマホ習慣」。
/// 本アプリが解こうとしている課題に近いものほど強い動機づけになるため、この順で最初に該当したものだけを返す
func ritualSummaryNote(
    undoneGoal: OnboardingUndoneGoalAnswer?,
    wake: OnboardingWakeAnswer?,
    satisfaction: OnboardingMorningSatisfactionAnswer?,
    dayBegin: OnboardingDayBeginAnswer?,
    firstMinutes: OnboardingFirstMinutesAnswer?
) -> RitualSummaryNote {
    if undoneGoal == .undone {
        return .answerSomeday
    }
    if wake == .almostNever {
        return .noMoreSnoozing
    }
    if satisfaction == .notReally {
        return .proudMornings
    }
    if dayBegin == .evening {
        return .dayBeginsMorning
    }
    if firstMinutes == .scrolling {
        return .firstMinutesToQuestion
    }
    return .startsTomorrow
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

/// 指定した日付の西暦年を返す。
/// 端末のカレンダー設定 (和暦・仏暦等) に依存せず西暦で数えるため、autoupdatingCurrent ではなくグレゴリオ暦から取る
/// (和暦の端末では component(.year:) が 8 のような元号内の年を返し、生まれ年ホイールの範囲 1900...現在年 が
/// 不正な ClosedRange になってクラッシュする)
func gregorianYear(date: Date) -> Int {
    Calendar(identifier: .gregorian).component(.year, from: date)
}

/// 生まれ年から、これまでに迎えた朝と残りの朝の回数を求める。
/// 生まれ年が未回答 (0)・未来の年・平均寿命に達している場合は、回数を出さず .unknown を返す
/// (残りが 0 以下になる人に「残り 0 回」と突きつけないため)
func morningsResultVariant(birthYear: Int, currentYear: Int) -> MorningsResultVariant {
    guard birthYear != 0 else { return .unknown }
    let age = currentYear - birthYear
    guard age >= 0, age < averageLifeExpectancyYears else { return .unknown }
    return .counted(lived: age * 365, remaining: (averageLifeExpectancyYears - age) * 365)
}
