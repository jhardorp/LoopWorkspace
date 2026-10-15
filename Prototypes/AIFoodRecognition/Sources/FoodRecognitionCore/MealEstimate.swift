import Foundation

/// These are prototype input limits, not clinical or dosing recommendations.
public enum PrototypeLimits {
    public static let carbohydrates = 0.0...250.0
    public static let absorptionMinutes = 30.0...480.0
    public static let maximumPhotoBytes = 5 * 1024 * 1024
}

public enum EstimateConfidence: String, Codable, Sendable {
    case low, moderate
}

/// An uncertainty interval supplied by the estimator; not a statistical confidence interval.
public struct EstimatedQuantity: Codable, Equatable, Sendable {
    public let value: Double
    public let lower: Double
    public let upper: Double

    public init(_ value: Double, lower: Double, upper: Double) {
        self.value = value
        self.lower = lower
        self.upper = upper
    }

    func isValid(in limits: ClosedRange<Double>) -> Bool {
        [lower, value, upper].allSatisfy { $0.isFinite && limits.contains($0) }
            && lower <= value && value <= upper
    }
}

public struct FoodEstimate: Codable, Equatable, Sendable {
    public let name: String
    public let portionDescription: String
    public let portionGrams: EstimatedQuantity
    public let carbohydrateGrams: EstimatedQuantity
    public let fatGrams: Double
    public let proteinGrams: Double
    public let fiberGrams: Double
    public let carbohydrateType: String
    public let glycemicCharacteristics: String
}

public struct MealEstimate: Codable, Equatable, Sendable {
    public let foods: [FoodEstimate]
    public let carbohydrateGrams: EstimatedQuantity
    public let absorptionMinutes: EstimatedQuantity
    public let confidence: EstimateConfidence
    public let assumptions: [String]
    public let absorptionRationale: String
    public let provenance: String

    /// Every provider response must pass this boundary before it reaches the review screen.
    public func validated() throws -> MealEstimate {
        guard !foods.isEmpty, foods.count <= 30,
              carbohydrateGrams.isValid(in: PrototypeLimits.carbohydrates),
              absorptionMinutes.isValid(in: PrototypeLimits.absorptionMinutes),
              !absorptionRationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !provenance.isEmpty, !assumptions.isEmpty else {
            throw EstimationError.invalidResponse
        }
        for food in foods {
            guard !food.name.isEmpty, !food.portionDescription.isEmpty,
                  !food.carbohydrateType.isEmpty, !food.glycemicCharacteristics.isEmpty,
                  food.portionGrams.isValid(in: 0.1...10_000),
                  food.carbohydrateGrams.isValid(in: PrototypeLimits.carbohydrates),
                  [food.fatGrams, food.proteinGrams, food.fiberGrams].allSatisfy({
                      $0.isFinite && (0...10_000).contains($0)
                  }) else {
                throw EstimationError.invalidResponse
            }
        }
        let summedCarbs = foods.reduce(0) { $0 + $1.carbohydrateGrams.value }
        guard abs(summedCarbs - carbohydrateGrams.value) <= 0.5 else {
            throw EstimationError.invalidResponse
        }
        return self
    }
}
