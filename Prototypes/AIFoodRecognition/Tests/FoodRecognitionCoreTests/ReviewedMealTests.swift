import XCTest
@testable import FoodRecognitionCore

final class ReviewedMealTests: XCTestCase {
    private func draft() async throws -> ReviewDraft {
        let result = try await MockFoodEstimator(delayNanoseconds: 0).estimate(photo: .demo)
        guard case .estimate(let estimate) = result else { throw EstimationError.invalidResponse }
        return ReviewDraft(estimate: estimate)
    }

    func testLoopReceivesEditedValuesUsingTheCurrentLocale() async throws {
        var review = try await draft()
        review.carbohydrateText = "12,5"
        review.absorptionMinutesText = "90,5"
        review.mealNotes = "  My edited meal  "
        let meal = try XCTUnwrap(ReviewedMeal(draft: review, locale: Locale(identifier: "de_DE")))
        XCTAssertEqual(meal.carbohydrateGrams, 12.5)
        XCTAssertEqual(meal.absorptionMinutes, 90.5)
        XCTAssertEqual(meal.foodDescription, "My edited meal")
    }

    func testMalformedOrOutOfRangeValuesCannotBeTransferred() async throws {
        var review = try await draft()
        for value in ["", "-1", "251", "nan", "1e2", "12abc"] {
            review.carbohydrateText = value
            XCTAssertNil(ReviewedMeal(draft: review), value)
        }
        review.carbohydrateText = "20"
        for value in ["", "29", "481", "inf", "-30"] {
            review.absorptionMinutesText = value
            XCTAssertNil(ReviewedMeal(draft: review), value)
        }
        review.absorptionMinutesText = "180"
        review.mealNotes = String(repeating: "x", count: 2049)
        XCTAssertNil(ReviewedMeal(draft: review))
    }
}
