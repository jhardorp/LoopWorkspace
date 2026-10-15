import Foundation
import XCTest
@testable import FoodRecognitionCore

@MainActor
final class MealRefinementTests: XCTestCase {
    private func fixture(_ scenario: MockScenario = .balancedMeal) async throws -> MealEstimate {
        let result = try await MockFoodEstimator(scenario: scenario, delayNanoseconds: 0).estimate(photo: .demo)
        guard case .estimate(let estimate) = result else { throw EstimationError.invalidResponse }
        return estimate
    }

    func testSuccessiveCorrectionsUseLatestEstimateAndTransferRevisedValues() async throws {
        let original = try await fixture(), first = try await fixture(.highFatMeal), second = try await fixture(.uncertainPortion)
        let provider = RefinementProvider(original: original, outcomes: [.estimate(first), .estimate(second)])
        let session = MealEstimateSession()
        await session.analyze(photo: .demo, using: provider)
        await session.refine(photo: .demo, comment: " Bigger bread slice ", using: provider)
        XCTAssertEqual(session.state, .reviewing(first))
        await session.refine(photo: .demo, comment: "I eat two of those", using: provider)
        let contexts = await provider.contexts
        XCTAssertEqual(contexts[1].previousEstimate, first)
        XCTAssertEqual(contexts[1].comments, ["Bigger bread slice", "I eat two of those"])
        XCTAssertEqual(session.state, .reviewing(second))
        var draft = try XCTUnwrap(session.draft)
        XCTAssertFalse(draft.acknowledgesUncertainty)
        draft.acknowledgesUncertainty = true
        session.edit(draft)
        var delivered: ReviewedMeal?
        XCTAssertTrue(session.finishReview(accept: { delivered = $0; return true }))
        XCTAssertEqual(delivered?.carbohydrateGrams, second.carbohydrateGrams.value)
        XCTAssertEqual(delivered?.absorptionMinutes, second.absorptionMinutes.value)
        XCTAssertEqual(delivered?.foodDescription, second.foods.map(\.name).joined(separator: ", "))
    }

    func testClarificationRetainsCommentAndQuestionUntilAnswered() async throws {
        let original = try await fixture(), revised = try await fixture(.highFatMeal)
        let provider = RefinementProvider(original: original, outcomes: [.needsMoreInformation("Which item?"), .estimate(revised)])
        let session = MealEstimateSession()
        await session.analyze(photo: .demo, using: provider)
        await session.refine(photo: .demo, comment: "I eat two", using: provider)
        XCTAssertEqual(session.state, .reviewing(original))
        XCTAssertEqual(session.refinementQuestion, "Which item?")
        XCTAssertFalse(session.finishReview())
        await session.refine(photo: .demo, comment: "The bread", using: provider)
        let contexts = await provider.contexts
        XCTAssertEqual(contexts.last?.question, "Which item?")
        XCTAssertEqual(contexts.last?.comments, ["I eat two", "The bread"])
        XCTAssertNil(session.refinementQuestion)
        XCTAssertEqual(session.state, .reviewing(revised))
    }

    func testFailedUpdateRetainsOriginalAndManualEdits() async throws {
        let original = try await fixture()
        let provider = RefinementProvider(original: original, error: .networkUnavailable)
        let session = MealEstimateSession()
        await session.analyze(photo: .demo, using: provider)
        var draft = try XCTUnwrap(session.draft)
        draft.carbohydrateText = "37"
        draft.mealNotes = "My edited food name"
        session.edit(draft)
        await session.refine(photo: .demo, comment: "Unripe banana", using: provider)
        XCTAssertEqual(session.state, .reviewing(original))
        XCTAssertEqual(session.draft, draft)
        XCTAssertEqual(session.refinementError, .networkUnavailable)
        XCTAssertEqual(session.refinementComments, [])
        XCTAssertFalse(session.isRefining)
    }

    func testInvalidCommentNeverCallsProviderOrChangesDraft() async throws {
        let original = try await fixture()
        let provider = RefinementProvider(original: original)
        let session = MealEstimateSession()
        await session.analyze(photo: .demo, using: provider)
        let draft = session.draft
        for comment in [" \n", String(repeating: "é", count: 1025)] {
            await session.refine(photo: .demo, comment: comment, using: provider)
            XCTAssertEqual(session.refinementError, .invalidComment)
            XCTAssertEqual(session.draft, draft)
        }
        let contexts = await provider.contexts
        XCTAssertTrue(contexts.isEmpty)
    }

    func testPendingUpdateBlocksDeliveryAndDuplicateRequestsThenCancellationPreservesReview() async throws {
        let original = try await fixture(), revised = try await fixture(.highFatMeal)
        let session = MealEstimateSession(), provider = SuspendedRefinement(original: original)
        await session.analyze(photo: .demo, using: provider)
        let draft = session.draft
        let task = Task { await session.refine(photo: .demo, comment: "Two portions", using: provider) }
        while !(await provider.started) { await Task.yield() }
        XCTAssertTrue(session.isRefining)
        XCTAssertFalse(session.finishReview())
        await session.refine(photo: .demo, comment: "Duplicate", using: provider)
        let calls = await provider.calls
        XCTAssertEqual(calls, 1)
        task.cancel()
        session.cancelRefinement()
        await provider.complete(.estimate(revised))
        await task.value
        XCTAssertEqual(session.state, .reviewing(original))
        XCTAssertEqual(session.draft, draft)
        XCTAssertEqual(session.refinementComments, [])
        XCTAssertFalse(session.isRefining)
    }

    func testDiscardRejectsLateRefinementAndClearsCommentHistory() async throws {
        let original = try await fixture(), revised = try await fixture(.highFatMeal)
        let session = MealEstimateSession(), provider = SuspendedRefinement(original: original)
        await session.analyze(photo: .demo, using: provider)
        let task = Task { await session.refine(photo: .demo, comment: "Langnese Cornetto", using: provider) }
        while !(await provider.started) { await Task.yield() }
        session.reset()
        await provider.complete(.estimate(revised))
        await task.value
        XCTAssertEqual(session.state, .idle)
        XCTAssertNil(session.draft)
        XCTAssertEqual(session.refinementComments, [])
    }
}

private actor RefinementProvider: FoodEstimating {
    let original: MealEstimate
    var outcomes: [EstimationOutcome]
    let error: EstimationError?
    private(set) var contexts: [MealRefinement] = []
    init(original: MealEstimate, outcomes: [EstimationOutcome] = [], error: EstimationError? = nil) {
        self.original = original; self.outcomes = outcomes; self.error = error
    }
    func estimate(photo: MealPhoto) async throws -> EstimationOutcome { .estimate(original) }
    func refine(photo: MealPhoto, context: MealRefinement) async throws -> EstimationOutcome {
        contexts.append(context)
        if let error { throw error }
        return outcomes.removeFirst()
    }
}

private actor SuspendedRefinement: FoodEstimating {
    let original: MealEstimate
    private var pending: CheckedContinuation<EstimationOutcome, Never>?
    private(set) var calls = 0
    var started: Bool { pending != nil }
    init(original: MealEstimate) { self.original = original }
    func estimate(photo: MealPhoto) async throws -> EstimationOutcome { .estimate(original) }
    func refine(photo: MealPhoto, context: MealRefinement) async throws -> EstimationOutcome {
        calls += 1
        return await withCheckedContinuation { pending = $0 }
    }
    func complete(_ outcome: EstimationOutcome) { pending?.resume(returning: outcome); pending = nil }
}
