import Foundation

/// Test-only values. No HealthKit, app-group, filesystem or device dependency.
public struct SandboxMeal: Identifiable, Equatable, Sendable {
    public let id: String
    public let grams: Double
    public let absorptionSeconds: Double
    public let date: Date
    public let notes: String

    public init(id: String, grams: Double, absorptionSeconds: Double, date: Date, notes: String) {
        self.id = id
        self.grams = grams
        self.absorptionSeconds = absorptionSeconds
        self.date = date
        self.notes = notes
    }
}

public struct MemoryMealLedger: Sendable {
    public private(set) var meals: [SandboxMeal] = []
    public init() {}

    /// A second callback/save for an existing entry never changes the first save.
    @discardableResult
    public mutating func save(_ meal: SandboxMeal) -> Bool {
        guard !meal.id.isEmpty, meal.grams.isFinite, meal.grams > 0,
              meal.absorptionSeconds.isFinite, meal.absorptionSeconds > 0,
              meal.date.timeIntervalSinceReferenceDate.isFinite,
              !meals.contains(where: { $0.id == meal.id }) else { return false }
        meals.append(meal)
        return true
    }

    public mutating func clear() { meals.removeAll() }
}
