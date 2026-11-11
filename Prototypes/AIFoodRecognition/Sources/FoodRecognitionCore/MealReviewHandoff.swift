import Foundation

/// A review presentation can replace the editable entry once. It never persists an entry.
/// The host invalidates it on dismissal so a late callback cannot change another entry.
@MainActor
public final class MealReviewHandoff {
    private var activeRequest: UUID?

    public init() {}

    @discardableResult
    public func begin() -> UUID {
        let request = UUID()
        activeRequest = request
        return request
    }

    public func cancel() { activeRequest = nil }

    @discardableResult
    public func accept(_ meal: ReviewedMeal, request: UUID,
                       maximumCarbohydrateGrams: Double,
                       absorptionSeconds: ClosedRange<Double>,
                       apply: (ReviewedMeal) -> Void) -> Bool {
        guard activeRequest == request,
              maximumCarbohydrateGrams.isFinite, maximumCarbohydrateGrams >= 0,
              meal.carbohydrateGrams.isFinite, meal.absorptionMinutes.isFinite,
              (0...maximumCarbohydrateGrams).contains(meal.carbohydrateGrams),
              absorptionSeconds.contains(meal.absorptionMinutes * 60) else { return false }
        // Consume before invoking the host, including synchronous/reentrant callbacks.
        activeRequest = nil
        apply(meal)
        return true
    }
}
