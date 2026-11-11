import XCTest
@testable import MealPhotoSandboxSupport

final class MemoryMealLedgerTests: XCTestCase {
    private func meal(id: String = "one", grams: Double = 12.5, seconds: Double = 5430) -> SandboxMeal {
        SandboxMeal(id: id, grams: grams, absorptionSeconds: seconds,
                    date: Date(timeIntervalSince1970: 1234567890), notes: "Two slices\nBanana not ripe")
    }

    func testExplicitSavePreservesReviewedValuesAndTime() {
        var ledger = MemoryMealLedger()
        let value = meal()
        XCTAssertTrue(ledger.save(value))
        XCTAssertEqual(ledger.meals, [value])
    }

    func testRepeatedSaveCannotAddOrOverwriteAnEntry() {
        var ledger = MemoryMealLedger()
        XCTAssertTrue(ledger.save(meal()))
        XCTAssertFalse(ledger.save(meal(grams: 99)))
        XCTAssertEqual(ledger.meals, [meal()])
        XCTAssertTrue(ledger.save(meal(id: "two")))
        XCTAssertEqual(ledger.meals.count, 2)
    }

    func testInvalidValuesLeaveLedgerUnchanged() {
        var ledger = MemoryMealLedger()
        XCTAssertFalse(ledger.save(meal(id: "")))
        for value in [0, -1, Double.nan, Double.infinity] {
            XCTAssertFalse(ledger.save(meal(grams: value)))
            XCTAssertFalse(ledger.save(meal(seconds: value)))
        }
        XCTAssertTrue(ledger.meals.isEmpty)
    }

    func testCancellationDoesNotSaveAndNewSessionStartsEmpty() {
        var ledger = MemoryMealLedger()
        _ = meal() // A preview without an explicit save.
        XCTAssertTrue(ledger.meals.isEmpty)
        XCTAssertTrue(ledger.save(meal()))
        ledger.clear()
        XCTAssertTrue(ledger.meals.isEmpty)
        XCTAssertTrue(MemoryMealLedger().meals.isEmpty)
    }
}
