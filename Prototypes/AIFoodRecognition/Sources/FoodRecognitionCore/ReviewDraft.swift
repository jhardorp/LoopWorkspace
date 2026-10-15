import Foundation

/// Transient editable values. Deliberately has no conversion to Loop's therapy types.
public struct ReviewDraft: Equatable, Sendable {
    public var carbohydrateText: String
    public var absorptionMinutesText: String
    public var mealNotes: String
    public var acknowledgesUncertainty = false

    public init(estimate: MealEstimate) {
        carbohydrateText = String(estimate.carbohydrateGrams.value)
        absorptionMinutesText = String(estimate.absorptionMinutes.value)
        mealNotes = estimate.foods.map(\.name).joined(separator: ", ")
    }

    /// Accepts a dot or the locale decimal separator, never grouping or partial numbers.
    public static func decimal(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
        guard normalized.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
              let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    public func canFinish(estimate: MealEstimate, locale: Locale = .current) -> Bool {
        guard let carbs = Self.decimal(carbohydrateText, locale: locale),
              let minutes = Self.decimal(absorptionMinutesText, locale: locale),
              PrototypeLimits.carbohydrates.contains(carbs),
              PrototypeLimits.absorptionMinutes.contains(minutes) else { return false }
        return estimate.confidence != .low || acknowledgesUncertainty
    }
}
