import Foundation
import XCTest
@testable import FoodRecognitionCore

final class FoodRecognitionCoreTests: XCTestCase {
    private func fixture(_ scenario: MockScenario = .balancedMeal) async throws -> MealEstimate {
        let result = try await MockFoodEstimator(scenario: scenario, delayNanoseconds: 0).estimate(photo: .demo)
        guard case .estimate(let estimate) = result else {
            throw EstimationError.invalidResponse
        }
        return estimate
    }

    func testFixturesIncludePortionsCompositionUncertaintyAndValidTotals() async throws {
        for scenario in [MockScenario.balancedMeal, .highFatMeal, .uncertainPortion] {
            let estimate = try await fixture(scenario)
            XCTAssertEqual(try estimate.validated(), estimate)
            XCTAssertTrue(estimate.foods.allSatisfy { $0.portionGrams.value > 0 })
            XCTAssertTrue(estimate.foods.allSatisfy { !$0.carbohydrateType.isEmpty && !$0.glycemicCharacteristics.isEmpty })
            XCTAssertFalse(estimate.absorptionRationale.isEmpty)
            XCTAssertFalse(estimate.assumptions.isEmpty)
            XCTAssertGreaterThan(estimate.carbohydrateGrams.upper, estimate.carbohydrateGrams.lower)
        }
    }

    func testHighFatFixtureHasLongerDurationAndLowConfidence() async throws {
        let mixed = try await fixture()
        let fatty = try await fixture(.highFatMeal)
        XCTAssertGreaterThan(fatty.absorptionMinutes.value, mixed.absorptionMinutes.value)
        XCTAssertEqual(fatty.confidence, .low)
    }

    func testMockDoesNotInterpretPhoto() async throws {
        let provider = MockFoodEstimator(delayNanoseconds: 0)
        let photo = try MealPhoto(jpegData: Data([0xff, 0xd8, 0xff, 0xd9]))
        let captured = try await provider.estimate(photo: photo)
        let demo = try await provider.estimate(photo: .demo)
        XCTAssertEqual(captured, demo)
    }

    func testPhotoInputRejectsEmptyAndOversizePayloads() {
        XCTAssertThrowsError(try MealPhoto(jpegData: Data()))
        XCTAssertThrowsError(try MealPhoto(jpegData: Data(count: PrototypeLimits.maximumPhotoBytes + 1)))
    }

    func testMalformedRangesNonfiniteNumbersAndLimitsAreRejected() async throws {
        let valid = try await fixture()
        for quantity in [
            EstimatedQuantity(.nan, lower: 30, upper: 180),
            EstimatedQuantity(.infinity, lower: 30, upper: 180),
            EstimatedQuantity(180, lower: 200, upper: 300),
            EstimatedQuantity(180, lower: 30, upper: 100),
            EstimatedQuantity(180, lower: -1, upper: 300),
            EstimatedQuantity(481, lower: 30, upper: 481)
        ] {
            let malformed = MealEstimate(foods: valid.foods, carbohydrateGrams: valid.carbohydrateGrams,
                absorptionMinutes: quantity, confidence: valid.confidence, assumptions: valid.assumptions,
                absorptionRationale: valid.absorptionRationale, provenance: valid.provenance)
            XCTAssertThrowsError(try malformed.validated())
        }
    }

    func testBackendDecodedInvalidValuesAreRejected() async throws {
        let encoded = try JSONEncoder().encode(await fixture())
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        for mutation in ["total", "emptyFoods", "negativeFat", "invalidPortion", "missingAssumptions"] {
            var object = original
            switch mutation {
            case "total": object["carbohydrateGrams"] = ["value": 1, "lower": 0, "upper": 2]
            case "emptyFoods": object["foods"] = []
            case "missingAssumptions": object["assumptions"] = []
            default:
                var foods = try XCTUnwrap(object["foods"] as? [[String: Any]])
                if mutation == "negativeFat" { foods[0]["fatGrams"] = -1 }
                else { foods[0]["portionGrams"] = ["value": 0, "lower": 0, "upper": 0] }
                object["foods"] = foods
            }
            let invalid = try JSONDecoder().decode(MealEstimate.self, from: JSONSerialization.data(withJSONObject: object))
            XCTAssertThrowsError(try invalid.validated(), mutation)
        }
    }

    func testReviewRequiresValidValuesAndExplicitLowConfidenceAcknowledgment() async throws {
        let estimate = try await fixture(.uncertainPortion)
        var draft = ReviewDraft(estimate: estimate)
        XCTAssertFalse(draft.canFinish(estimate: estimate))
        draft.acknowledgesUncertainty = true
        XCTAssertTrue(draft.canFinish(estimate: estimate))
        for invalid in ["", "-1", "251", "nan", "inf", "1e2", "12abc", "12.3.4"] {
            draft.carbohydrateText = invalid
            XCTAssertFalse(draft.canFinish(estimate: estimate), invalid)
        }
        draft.carbohydrateText = "50"
        for invalid in ["", "0", "29", "481", "-30", "∞"] {
            draft.absorptionMinutesText = invalid
            XCTAssertFalse(draft.canFinish(estimate: estimate), invalid)
        }
    }

    func testLocaleDecimalsAndBoundaries() async throws {
        let estimate = try await fixture()
        var draft = ReviewDraft(estimate: estimate)
        draft.carbohydrateText = "12,5"
        draft.absorptionMinutesText = "180,5"
        XCTAssertTrue(draft.canFinish(estimate: estimate, locale: Locale(identifier: "de_DE")))
        XCTAssertFalse(draft.canFinish(estimate: estimate, locale: Locale(identifier: "en_US")))
        XCTAssertNil(ReviewDraft.decimal("1,234.5", locale: Locale(identifier: "de_DE")))
        for (carbs, minutes) in [("0", "30"), ("250", "480")] {
            draft.carbohydrateText = carbs
            draft.absorptionMinutesText = minutes
            XCTAssertTrue(draft.canFinish(estimate: estimate))
        }
    }

    @MainActor
    func testSessionReviewEditsRemainTransientAndResetDiscardsThem() async throws {
        let session = MealEstimateSession()
        XCTAssertFalse(session.finishReview())
        await session.analyze(photo: .demo, using: MockFoodEstimator(delayNanoseconds: 0))
        let estimate = try await fixture()
        XCTAssertEqual(session.state, .reviewing(estimate))
        var draft = try XCTUnwrap(session.draft)
        draft.carbohydrateText = "42"
        draft.absorptionMinutesText = "210"
        session.edit(draft)
        XCTAssertEqual(session.draft?.carbohydrateText, "42")
        XCTAssertEqual(session.state, .reviewing(estimate)) // Original estimate is unchanged.
        XCTAssertTrue(session.finishReview())
        XCTAssertTrue(session.reviewFinished)
        draft.carbohydrateText = "43"
        session.edit(draft)
        XCTAssertFalse(session.reviewFinished)
        session.reset()
        XCTAssertEqual(session.state, .idle)
        XCTAssertNil(session.draft)
        XCTAssertFalse(session.reviewFinished)
    }

    @MainActor
    func testFailuresDiscardPreviousReviewAndRetryRecovers() async {
        let session = MealEstimateSession()
        for (scenario, error) in [(MockScenario.offline, EstimationError.networkUnavailable), (.timeout, .timedOut)] {
            await session.analyze(photo: .demo, using: MockFoodEstimator(delayNanoseconds: 0))
            XCTAssertNotNil(session.draft)
            await session.analyze(photo: .demo, using: MockFoodEstimator(scenario: scenario, delayNanoseconds: 0))
            XCTAssertEqual(session.state, .failed(error))
            XCTAssertNil(session.draft)
            XCTAssertFalse(session.finishReview())
        }
        await session.analyze(photo: .demo, using: MockFoodEstimator(delayNanoseconds: 0))
        XCTAssertNotNil(session.draft)
    }

    @MainActor
    func testUnrecognizableMealHasNoNumericFallback() async {
        let session = MealEstimateSession()
        await session.analyze(photo: .demo, using: MockFoodEstimator(scenario: .unrecognizable, delayNanoseconds: 0))
        guard case .needsMoreInformation = session.state else { return XCTFail("Expected clarification, not an estimate") }
        XCTAssertNil(session.draft)
        XCTAssertFalse(session.finishReview())
    }

    @MainActor
    func testProviderValidationOccursBeforeReview() async throws {
        let valid = try await fixture()
        let invalid = MealEstimate(foods: [], carbohydrateGrams: valid.carbohydrateGrams,
            absorptionMinutes: valid.absorptionMinutes, confidence: .moderate, assumptions: [],
            absorptionRationale: "", provenance: "")
        let session = MealEstimateSession()
        await session.analyze(photo: .demo, using: ImmediateEstimator(outcome: .estimate(invalid)))
        XCTAssertEqual(session.state, .failed(.invalidResponse))
        XCTAssertNil(session.draft)
    }

    @MainActor
    func testLateResponseCannotRestoreDiscardedReview() async throws {
        let session = MealEstimateSession()
        let provider = GatedEstimator()
        let task = Task { await session.analyze(photo: .demo, using: provider) }
        await provider.waitUntilRequested()
        XCTAssertEqual(session.state, .estimating)
        session.reset()
        await provider.resolve(.estimate(try await fixture()))
        await task.value
        XCTAssertEqual(session.state, .idle)
        XCTAssertNil(session.draft)
    }

    @MainActor
    func testOlderResponseCannotReplaceNewerEstimate() async throws {
        let session = MealEstimateSession()
        let provider = GatedEstimator()
        let first = Task { await session.analyze(photo: .demo, using: provider) }
        await provider.waitUntilRequested()
        await session.analyze(photo: .demo, using: MockFoodEstimator(scenario: .highFatMeal, delayNanoseconds: 0))
        let expected = session.state
        await provider.resolve(.estimate(try await fixture()))
        await first.value
        XCTAssertEqual(session.state, expected)
    }

    @MainActor
    func testAlreadyCancelledRequestCannotDisplaceActiveRequest() async throws {
        let session = MealEstimateSession()
        let provider = GatedEstimator()
        let active = Task { await session.analyze(photo: .demo, using: provider) }
        await provider.waitUntilRequested()
        let cancelled = Task {
            await session.analyze(photo: .demo, using: MockFoodEstimator(scenario: .offline, delayNanoseconds: 0))
        }
        cancelled.cancel()
        await cancelled.value
        XCTAssertEqual(session.state, .estimating)
        let estimate = try await fixture()
        await provider.resolve(.estimate(estimate))
        await active.value
        XCTAssertEqual(session.state, .reviewing(estimate))
    }

    @MainActor
    func testCancelledResponseProducesNoReview() async throws {
        let session = MealEstimateSession()
        let provider = GatedEstimator()
        let task = Task { await session.analyze(photo: .demo, using: provider) }
        await provider.waitUntilRequested()
        task.cancel()
        await provider.resolve(.estimate(try await fixture()))
        await task.value
        XCTAssertEqual(session.state, .idle)
        XCTAssertNil(session.draft)
    }
}

private struct ImmediateEstimator: FoodEstimating {
    let outcome: EstimationOutcome
    func estimate(photo: MealPhoto) async throws -> EstimationOutcome { outcome }
}

/// A deliberately cancellation-ignoring provider, so stale-response tests exercise the session boundary.
private actor GatedEstimator: FoodEstimating {
    private var response: CheckedContinuation<EstimationOutcome, Never>?
    private var requested = false
    private var waiter: CheckedContinuation<Void, Never>?

    func estimate(photo: MealPhoto) async throws -> EstimationOutcome {
        await withCheckedContinuation { continuation in
            response = continuation
            requested = true
            waiter?.resume()
            waiter = nil
        }
    }

    func waitUntilRequested() async {
        if requested { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func resolve(_ outcome: EstimationOutcome) {
        response?.resume(returning: outcome)
        response = nil
    }
}
