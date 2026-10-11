import XCTest
@testable import MementoMorning

final class QuestionRevisitMilestoneTests: XCTestCase {
    func testNotPresentedBeforeNinetyAnswers() {
        XCTAssertFalse(shouldPresentQuestionRevisitMilestone(answerCount: 89, isPresented: false, isPremium: true))
    }

    func testPresentedAtNinetyAnswersForPremium() {
        XCTAssertTrue(shouldPresentQuestionRevisitMilestone(answerCount: 90, isPresented: false, isPremium: true))
        XCTAssertTrue(shouldPresentQuestionRevisitMilestone(answerCount: 120, isPresented: false, isPremium: true))
    }

    func testNotPresentedAgainOncePresented() {
        XCTAssertFalse(shouldPresentQuestionRevisitMilestone(answerCount: 90, isPresented: true, isPremium: true))
    }

    func testNotPresentedForFreeUsers() {
        XCTAssertFalse(shouldPresentQuestionRevisitMilestone(answerCount: 90, isPresented: false, isPremium: false))
    }

    func testAnswerDescriptorPicksOneAnswerByOrdinal() {
        XCTAssertEqual(questionRevisitAnswerDescriptor(number: 1).fetchOffset, 0)
        XCTAssertEqual(questionRevisitAnswerDescriptor(number: 1).fetchLimit, 1)
        XCTAssertEqual(questionRevisitAnswerDescriptor(number: 90).fetchOffset, 89)
        XCTAssertEqual(questionRevisitAnswerDescriptor(number: 90).fetchLimit, 1)
    }

    func testReadyWaitsOnlyForPendingTranscription() {
        XCTAssertTrue(isQuestionRevisitReady(videoTranscriptionStatuses: [nil, nil]))
        XCTAssertTrue(isQuestionRevisitReady(videoTranscriptionStatuses: [.completed, .failed]))
        XCTAssertFalse(isQuestionRevisitReady(videoTranscriptionStatuses: [nil, .pending]))
        XCTAssertFalse(isQuestionRevisitReady(videoTranscriptionStatuses: [nil]))
    }
}
