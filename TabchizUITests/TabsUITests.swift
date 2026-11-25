import XCTest

nonisolated final class TabsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testANewBrowserStartsWithOneBlankTab() {
        let app = BrowserApp.launch()

        XCTAssertTrue(app.tab(0).waitForExistence(timeout: 5))
        XCTAssertEqual(app.tab(0).label, "新規タブ")
        XCTAssertTrue(app.tab(0).isSelected)
        XCTAssertFalse(app.tab(1).exists)
        XCTAssertEqual(app.pinsAndClusters.count, 0)
    }

    @MainActor
    func testSearchingAPresetShowsItsResultsInTheTab() {
        let app = BrowserApp.launch()

        app.preset("スーパー").tap()

        app.waitForResults("25件")
        XCTAssertEqual(app.tab(0).label, "スーパー")
        XCTAssertEqual(app.searchField.value as? String, "スーパー")
        XCTAssertGreaterThan(app.pinsAndClusters.count, 0)
    }

    @MainActor
    func testSearchingFreeText() {
        let app = BrowserApp.launch()

        app.searchField.tap()
        app.searchField.typeText("ラーメン")
        app.app.buttons["confirmQueryButton"].tap()

        app.waitForResults("0件")
        XCTAssertEqual(app.tab(0).label, "ラーメン")
    }

    @MainActor
    func testANewTabIsBlankAndComesToTheFront() {
        let app = BrowserApp.launch(seeding: ["スーパー"])
        app.waitForResults("25件")

        app.newTabButton.tap()

        XCTAssertTrue(app.tab(1).waitForExistence(timeout: 5))
        XCTAssertTrue(app.tab(1).isSelected)
        XCTAssertEqual(app.tab(1).label, "新規タブ")
        XCTAssertTrue(app.preset("ジム").waitForExistence(timeout: 5))
        XCTAssertEqual(app.pinsAndClusters.count, 0)
    }

    @MainActor
    func testClosingATabFromItsContextMenu() {
        let app = BrowserApp.launch(seeding: ["スーパー", "ジム"])
        XCTAssertTrue(app.tab(1).waitForExistence(timeout: 5))

        app.tab(0).press(forDuration: 1.2)
        let close = app.app.buttons["closeTabAction"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()

        XCTAssertTrue(app.tab(1).waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.tab(0).label, "ジム")
        XCTAssertTrue(app.tab(0).isSelected)
        XCTAssertEqual(app.searchField.value as? String, "ジム")
    }

    @MainActor
    func testNoSixthTabCanBeOpened() {
        let app = BrowserApp.launch(seeding: ["スーパー", "ジム", "カフェ", "薬局"])
        XCTAssertTrue(app.tab(3).waitForExistence(timeout: 5))
        XCTAssertTrue(app.newTabButton.isEnabled)

        app.newTabButton.tap()

        XCTAssertTrue(app.tab(4).waitForExistence(timeout: 5))
        XCTAssertFalse(app.newTabButton.isEnabled)
        XCTAssertEqual(app.newTabButton.label, "タブは5個までです")
        XCTAssertFalse(app.tab(5).exists)
    }
}
