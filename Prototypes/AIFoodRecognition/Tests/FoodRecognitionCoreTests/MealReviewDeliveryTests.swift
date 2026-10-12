import XCTest
@testable import FoodRecognitionCore

final class MealReviewDeliveryTests: XCTestCase {
    @MainActor
    func testRejectedDeliveryKeepsTheResultEditableAndCanBeRetried() async throws {
        let session = MealEstimateSession()
        await session.analyze(photo: .demo, using: MockFoodEstimator(delayNanoseconds: 0))
        let originalState = session.state
        let originalDraft = try XCTUnwrap(session.draft)
        var attempts = 0
        XCTAssertFalse(session.finishReview { _ in
            attempts += 1
            return false
        })
        XCTAssertFalse(session.reviewFinished)
        XCTAssertEqual(session.state, originalState)
        XCTAssertEqual(session.draft, originalDraft)

        var edited = originalDraft
        edited.carbohydrateText = "12,5"
        edited.absorptionMinutesText = "90"
        edited.mealNotes = "  Energy gel  "
        session.edit(edited)
        var delivered: ReviewedMeal?
        XCTAssertTrue(session.finishReview(locale: Locale(identifier: "de_DE")) { meal in
            attempts += 1
            delivered = meal
            return true
        })
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(delivered?.carbohydrateGrams, 12.5)
        XCTAssertEqual(delivered?.absorptionMinutes, 90)
        XCTAssertEqual(delivered?.foodDescription, "Energy gel")
        XCTAssertTrue(session.reviewFinished)
    }

    @MainActor
    func testCompletedReviewIsDeliveredOnlyOnceAndLeavesItsNumbersVisible() async throws {
        let session = MealEstimateSession()
        await session.analyze(photo: .demo, using: MockFoodEstimator(delayNanoseconds: 0))
        var deliveries = 0
        let accept: (ReviewedMeal) -> Bool = { _ in deliveries += 1; return true }
        XCTAssertTrue(session.finishReview(accept: accept))
        XCTAssertFalse(session.finishReview(accept: accept))
        XCTAssertEqual(deliveries, 1)
        XCTAssertNotNil(session.draft)
        guard case .reviewing = session.state else { return XCTFail("The result must remain visible") }
    }

    @MainActor
    func testLowConfidenceAndInvalidValuesAreNotDelivered() async throws {
        let session = MealEstimateSession()
        await session.analyze(photo: .demo, using: MockFoodEstimator(scenario: .uncertainPortion, delayNanoseconds: 0))
        let accept: (ReviewedMeal) -> Bool = { _ in XCTFail("Unreviewed or invalid input was delivered"); return true }
        XCTAssertFalse(session.finishReview(accept: accept))
        var draft = try XCTUnwrap(session.draft)
        draft.acknowledgesUncertainty = true
        draft.carbohydrateText = "251"
        session.edit(draft)
        XCTAssertFalse(session.finishReview(accept: accept))
        XCTAssertFalse(session.reviewFinished)
        draft.carbohydrateText = "30"
        session.edit(draft)
        XCTAssertTrue(session.finishReview { _ in true })
    }
}
