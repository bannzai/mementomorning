import XCTest
@testable import MementoMorning

final class OneMonthLetterTests: XCTestCase {
    func testFirstLetterIsFreeAfterThirtyAnswers() {
        XCTAssertNil(nextOneMonthLetterNumber(answerCount: 29, lastPresentedNumber: 0, isPremium: false))
        XCTAssertEqual(nextOneMonthLetterNumber(answerCount: 30, lastPresentedNumber: 0, isPremium: false), 1)
    }

    func testSecondLetterRequiresPremium() {
        XCTAssertNil(nextOneMonthLetterNumber(answerCount: 60, lastPresentedNumber: 1, isPremium: false))
        XCTAssertEqual(nextOneMonthLetterNumber(answerCount: 60, lastPresentedNumber: 1, isPremium: true), 2)
    }

    func testLettersArePresentedOldestFirstWhenSeveralAreReady() {
        XCTAssertEqual(nextOneMonthLetterNumber(answerCount: 90, lastPresentedNumber: 0, isPremium: false), 1)
        XCTAssertEqual(nextOneMonthLetterNumber(answerCount: 90, lastPresentedNumber: 1, isPremium: true), 2)
        XCTAssertEqual(nextOneMonthLetterNumber(answerCount: 90, lastPresentedNumber: 2, isPremium: true), 3)
    }

    func testPresentedLetterIsNotPresentedAgain() {
        XCTAssertNil(nextOneMonthLetterNumber(answerCount: 30, lastPresentedNumber: 1, isPremium: true))
        XCTAssertNil(nextOneMonthLetterNumber(answerCount: 60, lastPresentedNumber: 2, isPremium: true))
    }

    func testMostFrequentEnglishWordIgnoresCaseAndStopWords() {
        let texts = [
            "Be with my Family",
            "Call the family today",
            "FAMILY comes first",
        ]

        XCTAssertEqual(mostFrequentMeaningfulWord(in: texts), "Family")
    }

    func testMostFrequentJapaneseWordIgnoresParticles() {
        let texts = [
            "家族と海へ行く",
            "家族に手紙を書く",
            "今日は家族と過ごす",
        ]

        XCTAssertEqual(mostFrequentMeaningfulWord(in: texts), "家族")
    }

    func testMostFrequentSpanishWordIgnoresFunctionWords() {
        let texts = [
            "La familia y la familia",
            "Que la familia esté cerca",
        ]

        XCTAssertEqual(mostFrequentMeaningfulWord(in: texts), "familia")
    }

    func testTieUsesWordThatAppearedFirst() {
        XCTAssertEqual(mostFrequentMeaningfulWord(in: ["Ocean family", "family ocean"]), "Ocean")
    }

    func testLetterWaitsForAllAnswersAndVideoTranscription() {
        let completedStatuses: [VideoTranscriptionStatus?] = Array(repeating: nil, count: oneMonthLetterAnswerCount)
        XCTAssertTrue(
            isOneMonthLetterReady(
                answerCount: oneMonthLetterAnswerCount,
                videoTranscriptionStatuses: completedStatuses
            )
        )
        XCTAssertFalse(
            isOneMonthLetterReady(
                answerCount: oneMonthLetterAnswerCount - 1,
                videoTranscriptionStatuses: Array(completedStatuses.dropLast())
            )
        )

        var pendingStatuses = completedStatuses
        pendingStatuses[29] = .pending
        XCTAssertFalse(
            isOneMonthLetterReady(
                answerCount: oneMonthLetterAnswerCount,
                videoTranscriptionStatuses: pendingStatuses
            )
        )

        pendingStatuses[29] = .failed
        XCTAssertTrue(
            isOneMonthLetterReady(
                answerCount: oneMonthLetterAnswerCount,
                videoTranscriptionStatuses: pendingStatuses
            )
        )
    }
}
