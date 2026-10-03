import XCTest

final class ClipSpaceUITests: XCTestCase {
    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPrimaryClipJourney() throws {
        let app = launchApp()
        completeOnboarding(in: app)
        addClip(title: "Beta Journey", content: "Searchable beta content", sensitive: false, in: app)

        let searchField = app.textFields["Search your clips"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("Beta Journey")

        let row = app.buttons["clipRow_Beta Journey"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()

        let copyButton = app.buttons["Copy"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: 3))
        copyButton.tap()

        app.buttons["Pin"].tap()
        app.buttons["deleteClipButton"].tap()
        let deleteConfirmation = app.buttons["Delete Clip"]
        XCTAssertTrue(deleteConfirmation.waitForExistence(timeout: 2))
        deleteConfirmation.tap()
        XCTAssertFalse(row.waitForExistence(timeout: 2))
    }

    @MainActor
    func testSensitiveClipIsMaskedUntilExplicitReveal() throws {
        let app = launchApp(additionalArguments: ["--ui-testing-sensitive-clip"])
        completeOnboarding(in: app)
        addClip(title: "Private Note", content: "private-beta-value", sensitive: true, in: app)

        XCTAssertFalse(app.staticTexts["private-beta-value"].exists)
        let row = app.buttons["clipRow_Private Note"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()

        XCTAssertFalse(app.staticTexts["private-beta-value"].exists)
        let reveal = app.buttons["revealSensitiveContentButton"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 3))
        reveal.tap()
        XCTAssertTrue(app.staticTexts["private-beta-value"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func launchApp(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + additionalArguments
        app.launch()
        return app
    }

    @MainActor
    private func completeOnboarding(in app: XCUIApplication) {
        let button = app.buttons["Get Started"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        button.tap()
    }

    @MainActor
    private func addClip(title: String, content: String, sensitive: Bool, in app: XCUIApplication) {
        let addButton = app.buttons["addClipButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        if sensitive {
            let sensitiveToggle = app.switches["Sensitive Content"]
            XCTAssertTrue(sensitiveToggle.waitForExistence(timeout: 2))
            XCTAssertEqual(sensitiveToggle.value as? String, "1")
        }

        let titleField = app.textFields["clipTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText(title)

        let contentField = app.textFields["clipContentField"]
        contentField.tap()
        contentField.typeText(content)

        app.buttons["Add"].tap()
        XCTAssertFalse(titleField.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["clipRow_\(title)"].waitForExistence(timeout: 3))
    }
}
