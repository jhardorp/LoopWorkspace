import XCTest
@testable import FoodRecognitionCore

@MainActor
final class MealReviewHandoffTests: XCTestCase {
    private func reviewedMeal() async throws -> ReviewedMeal {
        let session = MealEstimateSession()
        await session.analyze(photo: .demo, using: MockFoodEstimator(delayNanoseconds: 0))
        var draft = try XCTUnwrap(session.draft)
        draft.carbohydrateText = "12,5"
        draft.absorptionMinutesText = "90,5"
        draft.mealNotes = "Two slices, large portion"
        session.edit(draft)
        var meal: ReviewedMeal?
        XCTAssertTrue(session.finishReview(locale: Locale(identifier: "de_DE")) { meal = $0; return true })
        return try XCTUnwrap(meal)
    }

    func testDuplicateAndReentrantCallbacksTransferOnlyOnce() async throws {
        let handoff = MealReviewHandoff(), meal = try await reviewedMeal()
        let request = handoff.begin()
        var count = 0
        XCTAssertTrue(handoff.accept(meal, request: request, maximumCarbohydrateGrams: 250, absorptionSeconds: 1800...28800) { value in
            count += 1
            XCTAssertEqual(value.carbohydrateGrams, 12.5)
            XCTAssertEqual(value.absorptionMinutes * 60, 5430)
            XCTAssertEqual(value.foodDescription, "Two slices, large portion")
            XCTAssertFalse(handoff.accept(meal, request: request, maximumCarbohydrateGrams: 250, absorptionSeconds: 1800...28800) { _ in count += 1 })
        })
        XCTAssertFalse(handoff.accept(meal, request: request, maximumCarbohydrateGrams: 250, absorptionSeconds: 1800...28800) { _ in count += 1 })
        XCTAssertEqual(count, 1)
    }

    func testDismissedAndSupersededPresentationsCannotTransfer() async throws {
        let handoff = MealReviewHandoff(), meal = try await reviewedMeal()
        let cancelled = handoff.begin()
        handoff.cancel()
        XCTAssertFalse(handoff.accept(meal, request: cancelled, maximumCarbohydrateGrams: 250, absorptionSeconds: 1800...28800) { _ in XCTFail("Cancelled review transferred") })
        let old = handoff.begin(), current = handoff.begin()
        XCTAssertFalse(handoff.accept(meal, request: old, maximumCarbohydrateGrams: 250, absorptionSeconds: 1800...28800) { _ in XCTFail("Stale review transferred") })
        XCTAssertTrue(handoff.accept(meal, request: current, maximumCarbohydrateGrams: 250, absorptionSeconds: 1800...28800) { _ in })
    }

    func testNativeLimitsRejectWithoutConsumingReviewOrMutatingHost() async throws {
        let handoff = MealReviewHandoff(), meal = try await reviewedMeal(), request = handoff.begin()
        XCTAssertFalse(handoff.accept(meal, request: request, maximumCarbohydrateGrams: 10, absorptionSeconds: 1800...28800) { _ in XCTFail("Invalid carbs transferred") })
        XCTAssertFalse(handoff.accept(meal, request: request, maximumCarbohydrateGrams: 250, absorptionSeconds: 1800...5400) { _ in XCTFail("Invalid time transferred") })
        XCTAssertTrue(handoff.accept(meal, request: request, maximumCarbohydrateGrams: 250, absorptionSeconds: 1800...28800) { _ in })
    }

    func testCancellingCompletedAnalysisPreventsDelivery() async throws {
        let session = MealEstimateSession()
        await session.analyze(photo: .demo, using: MockFoodEstimator(delayNanoseconds: 0))
        session.reset()
        XCTAssertFalse(session.finishReview { _ in XCTFail("Discarded estimate delivered"); return true })
        XCTAssertNil(session.draft)
    }
}
