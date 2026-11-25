import XCTest

nonisolated final class TabSwitchingUITests: XCTestCase {
    /// テストジム01 is 0.0012 degrees of latitude north of it, which is 133 m, and テストスーパー02 is 0.0007 degrees
    /// north of テストジム01, which is 78 m. FixturePlaceSearcher describes the grid.
    private static let firstSupermarket = "テストスーパー01"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testEachTabShowsItsOwnQueryAndResults() {
        let app = BrowserApp.launch(seeding: ["スーパー", "ラーメン"])
        app.waitForResults("25件")
        XCTAssertTrue(app.tab(0).isSelected)
        XCTAssertEqual(app.searchField.value as? String, "スーパー")
        XCTAssertTrue(app.placeRow(Self.firstSupermarket).exists)
        XCTAssertGreaterThan(app.pinsAndClusters.count, 0)

        app.tab(1).tap()

        app.waitForResults("0件")
        XCTAssertTrue(app.tab(1).isSelected)
        XCTAssertFalse(app.tab(0).isSelected)
        XCTAssertEqual(app.searchField.value as? String, "ラーメン")
        XCTAssertFalse(app.placeRow(Self.firstSupermarket).exists)
        XCTAssertEqual(app.pinsAndClusters.count, 0)

        app.tab(0).tap()

        app.waitForResults("25件")
        XCTAssertEqual(app.searchField.value as? String, "スーパー")
        XCTAssertTrue(app.placeRow(Self.firstSupermarket).exists)
    }

    @MainActor
    func testATabKeepsItsPlacePageWhileAnotherTabIsOnScreen() {
        let app = BrowserApp.launch(seeding: ["スーパー", "ジム"])
        app.waitForResults("25件")
        app.placeRow(Self.firstSupermarket).tap()
        app.waitForPlace(Self.firstSupermarket)
        let nearestGym = app.app.buttons["nearest.ジム"]
        XCTAssertTrue(nearestGym.label.contains("テストジム01"))
        XCTAssertTrue(nearestGym.label.contains("直線 133 m"))

        app.tab(1).tap()

        app.waitForResults("25件")
        XCTAssertFalse(app.placeTitle.exists)
        XCTAssertFalse(app.backButton.exists)

        app.tab(0).tap()

        app.waitForPlace(Self.firstSupermarket)

        app.backButton.tap()

        app.waitForResults("25件")
        XCTAssertFalse(app.backButton.exists)
    }

    @MainActor
    func testPickingTheNearestPlaceOfAnotherTabOpensItInThatTab() {
        let app = BrowserApp.launch(seeding: ["スーパー", "ジム"])
        app.waitForResults("25件")
        app.placeRow(Self.firstSupermarket).tap()
        app.waitForPlace(Self.firstSupermarket)

        app.app.buttons["nearest.ジム"].tap()

        app.waitForPlace("テストジム01")
        XCTAssertTrue(app.tab(1).isSelected)
        XCTAssertEqual(app.searchField.value as? String, "ジム")
        XCTAssertTrue(app.app.buttons["nearest.スーパー"].label.contains("テストスーパー02"))
        XCTAssertTrue(app.app.buttons["nearest.スーパー"].label.contains("直線 78 m"))

        app.backButton.tap()

        app.waitForResults("25件")
        XCTAssertTrue(app.tab(1).isSelected)
    }
}
