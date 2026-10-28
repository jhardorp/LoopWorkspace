import Foundation

public enum MockScenario: String, CaseIterable, Sendable {
    case balancedMeal, highFatMeal, uncertainPortion, unrecognizable, offline, timeout
}

/// Fixed fictional data. The photo is deliberately not interpreted or transmitted.
public struct MockFoodEstimator: FoodEstimating {
    public let scenario: MockScenario
    private let delayNanoseconds: UInt64

    public init(scenario: MockScenario = .balancedMeal, delayNanoseconds: UInt64 = 600_000_000) {
        self.scenario = scenario
        self.delayNanoseconds = delayNanoseconds
    }

    public func estimate(photo: MealPhoto) async throws -> EstimationOutcome {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()
        switch scenario {
        case .offline: throw EstimationError.networkUnavailable
        case .timeout: throw EstimationError.timedOut
        case .unrecognizable:
            return .needsMoreInformation("The meal cannot be identified. Retake the photo or enter your own values; no estimate is available.")
        case .balancedMeal, .highFatMeal, .uncertainPortion:
            return .estimate(try Self.fixture(for: scenario).validated())
        }
    }

    public func estimate(description: MealDescription) async throws -> EstimationOutcome {
        try await estimate(photo: .demo)
    }

    private static func fixture(for scenario: MockScenario) -> MealEstimate {
        let highFat = scenario == .highFatMeal
        let uncertain = scenario == .uncertainPortion
        let foods: [FoodEstimate]
        if highFat {
            foods = [FoodEstimate(
                name: "Cheese pizza", portionDescription: "3 medium slices (fictional)",
                portionGrams: EstimatedQuantity(300, lower: 230, upper: 380),
                carbohydrateGrams: EstimatedQuantity(84, lower: 60, upper: 110),
                fatGrams: 30, proteinGrams: 33, fiberGrams: 5,
                carbohydrateType: "Refined flour starch",
                glycemicCharacteristics: "Starch may absorb rapidly; added fat can delay the mixed meal."
            )]
        } else {
            foods = [
                FoodEstimate(name: "Cooked brown rice", portionDescription: "1 cup (fictional)",
                    portionGrams: EstimatedQuantity(195, lower: 150, upper: 250),
                    carbohydrateGrams: EstimatedQuantity(45, lower: 34, upper: 58),
                    fatGrams: 2, proteinGrams: 5, fiberGrams: 4,
                    carbohydrateType: "Whole grain starch",
                    glycemicCharacteristics: "Fiber and preparation affect availability of starch."),
                FoodEstimate(name: "Chicken and vegetables", portionDescription: "1 serving (fictional)",
                    portionGrams: EstimatedQuantity(220, lower: 150, upper: 300),
                    carbohydrateGrams: EstimatedQuantity(20, lower: 12, upper: 32),
                    fatGrams: 12, proteinGrams: 30, fiberGrams: 6,
                    carbohydrateType: "Vegetable carbohydrate and possible sauce sugars",
                    glycemicCharacteristics: "Protein, fat, and fiber may delay the mixed meal.")
            ]
        }
        return MealEstimate(
            foods: foods,
            carbohydrateGrams: highFat ? EstimatedQuantity(84, lower: 60, upper: 110)
                : EstimatedQuantity(65, lower: 46, upper: 90),
            absorptionMinutes: highFat ? EstimatedQuantity(300, lower: 180, upper: 420)
                : EstimatedQuantity(180, lower: 90, upper: 300),
            confidence: highFat || uncertain ? .low : .moderate,
            assumptions: [
                "Demo values are fixed and unrelated to this photo.",
                uncertain ? "Portion scale, sauce, and cooking oil are unclear; verify every value."
                    : "Portions, cooking oil, and recipe are assumed. Confirm ingredients and amounts.",
                "The ranges are illustrative, not calibrated probabilities."
            ],
            absorptionRationale: highFat
                ? "This fixture uses a longer duration for a mixed meal with substantial fat and protein, despite refined starch. Fiber and recipe also matter. This is an unvalidated example, not a physiological prediction."
                : "This fixture uses a moderate duration for starch with fiber, fat, and protein. Carbohydrate type, glycemic characteristics, preparation, and portion size can change absorption. This is an unvalidated example, not a physiological prediction.",
            provenance: "Mock fixture v1 — no AI or nutrition lookup"
        )
    }
}
