import XCTest

final class SandboxUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["sandbox_new_entry"].waitForExistence(timeout: 30))
        return app
    }

    func testNativeEditorCancellationLeavesNoTestEntry() {
        let app = launch()
        app.buttons["sandbox_new_entry"].tap()
        XCTAssertTrue(app.buttons["button_Continue"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Photograph meal"].exists)
        XCTAssertTrue(app.buttons["Choose photo"].exists)
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.buttons["sandbox_new_entry"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["sandbox_count"].label.hasSuffix(": 0"))
    }

    func testNativeContinueSavesOnlyOneInMemoryEntry() {
        let app = launch()
        app.buttons["sandbox_new_entry"].tap()
        let quantity = app.textFields.firstMatch
        XCTAssertTrue(quantity.waitForExistence(timeout: 10))
        quantity.tap()
        quantity.typeText("12.5")
        app.buttons["button_Continue"].tap()
        let save = app.buttons["sandbox_save_entry"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        XCTAssertFalse(save.isEnabled)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["sandbox_new_entry"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["sandbox_count"].label.hasSuffix(": 1"))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["sandbox_new_entry"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["sandbox_count"].label.hasSuffix(": 0"))
    }
}
