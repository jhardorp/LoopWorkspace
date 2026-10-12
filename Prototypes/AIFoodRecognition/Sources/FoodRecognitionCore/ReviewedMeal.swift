import Foundation

/// Values explicitly accepted in the review screen, before Loop's normal entry validation.
public struct ReviewedMeal: Equatable, Sendable {
    public let carbohydrateGrams: Double
    public let absorptionMinutes: Double
    public let foodDescription: String

    public init?(draft: ReviewDraft, locale: Locale = .current) {
        guard let carbohydrates = ReviewDraft.decimal(draft.carbohydrateText, locale: locale),
              let minutes = ReviewDraft.decimal(draft.absorptionMinutesText, locale: locale),
              PrototypeLimits.carbohydrates.contains(carbohydrates),
              PrototypeLimits.absorptionMinutes.contains(minutes),
              draft.mealNotes.utf8.count <= 2048 else { return nil }
        carbohydrateGrams = carbohydrates
        absorptionMinutes = minutes
        foodDescription = draft.mealNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
