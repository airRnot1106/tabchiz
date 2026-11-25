import XCTest

nonisolated final class PinsUITests: XCTestCase {
    private static let firstSupermarket = "テストスーパー01"
    /// Points of the map above the sheet, as fractions of the map's width and height.
    private static let northWest = CGVector(dx: 0.2, dy: 0.22)
    private static let northEast = CGVector(dx: 0.8, dy: 0.17)
    private static let south = CGVector(dx: 0.6, dy: 0.42)

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testALongPressDropsAPinThatShowsOnTheMapAndInTheList() {
        let app = BrowserApp.launch()
        XCTAssertTrue(app.tab(0).waitForExistence(timeout: 5))
        XCTAssertFalse(app.pinsSummary.exists)

        app.dropPin(at: Self.northWest)

        app.waitForPins("ピン 1個")
        app.wait(for: app.pinRow(0), toSay: "テスト地点 1")
        XCTAssertTrue(app.mapPin("テスト地点 1", ofTab: 0).waitForExistence(timeout: 5))
        XCTAssertEqual(app.tab(0).label, "ピン")
        XCTAssertEqual(app.tab(0).value as? String, "ピン1個")
        XCTAssertTrue(app.preset("スーパー").exists)
        XCTAssertEqual(app.pinsAndClusters.count, 0)
    }

    @MainActor
    func testThreePinsCanBeDroppedInOneTab() {
        let app = BrowserApp.launch()
        XCTAssertTrue(app.tab(0).waitForExistence(timeout: 5))

        app.dropPin(at: Self.northWest)
        app.dropPin(at: Self.northEast)
        app.dropPin(at: Self.south)

        app.waitForPins("ピン 3個")
        for index in 0..<3 {
            app.wait(for: app.pinRow(index), toSay: "テスト地点 \(index + 1)")
            XCTAssertTrue(app.mapPin("テスト地点 \(index + 1)", ofTab: 0).waitForExistence(timeout: 5))
        }
        XCTAssertEqual(app.tab(0).value as? String, "ピン3個")
    }

    @MainActor
    func testAPlaceIsPinnedAndUnpinnedFromItsPlacePage() {
        let app = BrowserApp.launch(seeding: ["スーパー"])
        app.waitForResults("25件")
        app.placeRow(Self.firstSupermarket).tap()
        app.waitForPlace(Self.firstSupermarket)
        XCTAssertEqual(app.pinToggle.label, "ピンを刺す")

        app.pinToggle.tap()

        app.wait(for: app.pinToggle, toSay: "ピンを外す")
        XCTAssertTrue(app.mapPin(Self.firstSupermarket, ofTab: 0).waitForExistence(timeout: 5))
        app.backButton.tap()
        app.waitForPins("ピン 1個")
        XCTAssertEqual(app.pinRow(0).label, Self.firstSupermarket)
        XCTAssertEqual(app.placeRow(Self.firstSupermarket).value as? String, "ピン済み")
        app.waitForResults("25件")

        app.placeRow(Self.firstSupermarket).tap()
        app.waitForPlace(Self.firstSupermarket)
        app.pinToggle.tap()

        app.wait(for: app.pinToggle, toSay: "ピンを刺す")
        app.backButton.tap()
        app.waitForResults("25件")
        XCTAssertFalse(app.pinsSummary.exists)
        XCTAssertFalse(app.mapPin(Self.firstSupermarket, ofTab: 0).exists)
    }

    @MainActor
    func testAPlaceIsPinnedFromItsRowInTheResults() {
        let app = BrowserApp.launch(seeding: ["スーパー"])
        app.waitForResults("25件")

        app.placeRow(Self.firstSupermarket).swipeLeft()
        app.pinToggle.tap()

        app.waitForPins("ピン 1個")
        XCTAssertEqual(app.pinRow(0).label, Self.firstSupermarket)
        XCTAssertFalse(app.placeTitle.exists)
    }

    @MainActor
    func testPinsSurviveTabSwitchesAndARelaunch() {
        let app = BrowserApp.launch()
        XCTAssertTrue(app.tab(0).waitForExistence(timeout: 5))
        app.dropPin(at: Self.northWest)
        app.dropPin(at: Self.northEast)
        app.waitForPins("ピン 2個")
        app.pinRow(0).tap()
        app.waitForPin("テスト地点 1")
        app.renameViewedPin(to: "テスト住まい西")
        app.waitForPin("テスト住まい西")
        app.backButton.tap()

        app.newTabButton.tap()
        app.preset("ジム").tap()
        app.waitForResults("25件")
        XCTAssertFalse(app.pinsSummary.exists)
        app.tab(0).tap()

        app.waitForPins("ピン 2個")
        XCTAssertEqual(app.pinRow(0).label, "テスト住まい西")
        XCTAssertEqual(app.pinRow(1).label, "テスト地点 2")

        app.app.terminate()
        let relaunched = BrowserApp.launch(keepingSavedTabs: true)

        relaunched.waitForPins("ピン 2個")
        XCTAssertEqual(relaunched.pinRow(0).label, "テスト住まい西")
        XCTAssertEqual(relaunched.pinRow(1).label, "テスト地点 2")
        XCTAssertEqual(relaunched.tab(0).label, "ピン")
        XCTAssertEqual(relaunched.tab(1).label, "ジム")
        XCTAssertTrue(relaunched.mapPin("テスト住まい西", ofTab: 0).waitForExistence(timeout: 5))
    }

    @MainActor
    func testAPinPageShowsTheNearestSpotOfEachOtherTabAndRemovesThePin() {
        let app = BrowserApp.launch()
        XCTAssertTrue(app.tab(0).waitForExistence(timeout: 5))
        app.dropPin(at: Self.northWest)
        app.waitForPins("ピン 1個")
        app.newTabButton.tap()
        app.preset("スーパー").tap()
        app.waitForResults("25件")
        app.tab(0).tap()

        app.pinRow(0).tap()

        app.waitForPin("テスト地点 1")
        XCTAssertTrue(app.backButton.exists)
        XCTAssertTrue(app.nearest("スーパー").waitForExistence(timeout: 5))
        XCTAssertTrue(app.nearest("スーパー").label.contains("直線 "))

        app.expandSheet()
        app.app.buttons["removePinButton"].tap()

        XCTAssertTrue(app.pinTitle.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.pinsSummary.exists)
        XCTAssertFalse(app.backButton.exists)
        XCTAssertEqual(app.tab(0).label, "新規タブ")
        XCTAssertFalse(app.mapPin("テスト地点 1", ofTab: 0).exists)
    }

    @MainActor
    func testAPinSelectedInTheOverviewShowsItsNearestSpotsAndOpensInItsTab() {
        let app = BrowserApp.launch()
        XCTAssertTrue(app.tab(0).waitForExistence(timeout: 5))
        app.dropPin(at: Self.northWest)
        app.waitForPins("ピン 1個")
        app.newTabButton.tap()
        app.preset("スーパー").tap()
        app.waitForResults("25件")
        app.newTabButton.tap()
        app.preset("ジム").tap()
        app.waitForResults("25件")

        app.overviewTab.tap()

        XCTAssertTrue(app.overviewLegend.waitForExistence(timeout: 5))
        XCTAssertEqual(app.overviewLegend.label, "凡例 ピン ピン1個、スーパー、ジム")
        XCTAssertEqual(app.overviewSummary.label, "3タブ・50件・ピン 1個")
        // The overview map settles on every pin and place before the pin is tapped.
        sleep(2)
        let pin = app.mapPin("テスト地点 1", ofTab: 0)
        XCTAssertTrue(pin.exists)

        pin.tap()

        app.wait(for: app.overviewPinTitle, toSay: "テスト地点 1")
        XCTAssertTrue(app.overviewTab.isSelected)
        XCTAssertTrue(app.nearest("スーパー").waitForExistence(timeout: 5))
        XCTAssertTrue(app.nearest("スーパー").label.contains("直線 "))
        XCTAssertTrue(app.nearest("ジム").label.contains("直線 "))

        app.app.buttons["overviewPinCloseButton"].tap()

        XCTAssertTrue(app.overviewPinTitle.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.overviewTab.isSelected)
        XCTAssertTrue(app.app.buttons["overviewRow.0"].waitForExistence(timeout: 5))

        sleep(1)
        app.mapPin("テスト地点 1", ofTab: 0).tap()
        app.wait(for: app.overviewPinTitle, toSay: "テスト地点 1")
        app.expandSheet()
        app.app.buttons["openPinInTabButton"].tap()

        app.waitForPin("テスト地点 1")
        XCTAssertTrue(app.tab(0).isSelected)
        XCTAssertFalse(app.overviewTab.isSelected)
        XCTAssertTrue(app.nearest("ジム").waitForExistence(timeout: 5))
    }
}
