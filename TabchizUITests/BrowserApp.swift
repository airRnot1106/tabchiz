import XCTest

/// The app launched on the bundled invented places, with the elements the tests drive.
@MainActor
struct BrowserApp {
    let app: XCUIApplication

    /// Launches with empty saved tabs, with one tab per query, or with the tabs and pins the previous launch
    /// saved.
    static func launch(seeding queries: [String] = [], keepingSavedTabs: Bool = false) -> Self {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture"]
        if keepingSavedTabs {
            app.launchArguments += ["-KeepSavedTabs"]
        }
        if !queries.isEmpty {
            app.launchArguments += ["-SeedTabs", queries.joined(separator: ",")]
        }
        app.launch()
        return Self(app: app)
    }

    var searchField: XCUIElement { app.textFields["searchField"] }
    var newTabButton: XCUIElement { app.buttons["newTabButton"] }
    var backButton: XCUIElement { app.buttons["backButton"] }
    var placeTitle: XCUIElement { app.staticTexts["placeTitle"] }

    var overviewTab: XCUIElement { app.buttons["overviewTab"] }
    var overviewLegend: XCUIElement { app.descendants(matching: .any)["overviewLegend"] }
    var overviewSummary: XCUIElement { app.staticTexts["overviewSummary"] }

    var map: XCUIElement { app.descendants(matching: .any)["map"] }
    var pinsSummary: XCUIElement { app.staticTexts["pinsSummary"] }
    var pinTitle: XCUIElement { app.staticTexts["pinTitle"] }
    var pinToggle: XCUIElement { app.buttons["pinToggleButton"] }
    var overviewPinTitle: XCUIElement { app.staticTexts["overviewPinTitle"] }

    /// A row of the tab's pin list, in the order the pins were added.
    func pinRow(_ index: Int) -> XCUIElement {
        app.buttons["pinRow.\(index)"]
    }

    /// The marker of a pin of the tab at `index` on the map, by the pin's name.
    func mapPin(_ name: String, ofTab index: Int) -> XCUIElement {
        app.descendants(matching: .any)["mapPin.\(index).\(name)"]
    }

    /// The row of the nearest spot of the tab named `title`, on a place page, a pin page or the overview.
    func nearest(_ title: String) -> XCUIElement {
        app.buttons["nearest.\(title)"]
    }

    /// Presses the map long at a point given as fractions of its width and height. The sheet covers the lower
    /// half of the map, so `dy` stays below 0.45.
    func dropPin(at offset: CGVector) {
        map.coordinate(withNormalizedOffset: offset).press(forDuration: 1)
    }

    /// Pulls the sheet up to its full height, so the rows at the end of a page are on screen.
    func expandSheet() {
        let grabber = app.buttons["シートグラバー"]
        XCTAssertTrue(grabber.waitForExistence(timeout: 5))
        grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
    }

    /// Renames the pin whose page is on screen. The alert drops the identifiers of its field and buttons, so
    /// they are found by their place in the alert.
    func renameViewedPin(to name: String) {
        app.buttons["renamePinButton"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        if let old = field.value as? String {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        }
        field.typeText(name)
        app.alerts.buttons["保存"].tap()
    }

    /// The tab's item in the bar.
    func tab(_ index: Int) -> XCUIElement {
        app.buttons["tab.\(index)"]
    }

    func preset(_ name: String) -> XCUIElement {
        app.buttons["preset.\(name)"]
    }

    /// The markers of the tab on screen.
    var pinsAndClusters: XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'pin.' OR identifier BEGINSWITH 'cluster.'"))
    }

    /// A row of the results list on screen, by the place's name.
    func placeRow(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.' AND label == %@", name)).firstMatch
    }

    /// The bubble of the tab's places that overlap in the overview.
    func overviewCluster(ofTab index: Int) -> XCUIElement {
        app.descendants(matching: .any)["overviewCluster.\(index)"]
    }

    /// Drags the sheet up to its full height.
    func raiseSheet() {
        let summary = app.descendants(matching: .any)["resultsSummary"]
        let above = summary.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 0, dy: -60))
        above.press(forDuration: 0.1, thenDragTo: above.withOffset(CGVector(dx: 0, dy: -700)))
    }

    /// A dot of the tab in the overview that no other marker and no control covers, so a tap lands on it.
    func uncoveredOverviewDot(ofTab index: Int) -> XCUIElement? {
        let markers = app.descendants(matching: .any)
            .matching(
                NSPredicate(format: "identifier BEGINSWITH 'overviewPin.' OR identifier BEGINSWITH 'overviewCluster.'")
            )
            .allElementsBoundByIndex
        let frames = markers.map { (identifier: $0.identifier, frame: $0.frame) }
        let clear = CGRect(
            x: 0,
            y: overviewLegend.frame.maxY,
            width: app.frame.width,
            height: overviewSummary.frame.minY - 40 - overviewLegend.frame.maxY
        )
        return markers.first { dot in
            let frame = dot.frame
            return dot.identifier.hasPrefix("overviewPin.\(index).") && clear.contains(frame)
                && frames.allSatisfy {
                    $0.identifier == dot.identifier || !$0.frame.intersects(frame.insetBy(dx: -6, dy: -6))
                }
        }
    }

    /// Waits until the results page on screen reports `summary`, such as "25件".
    func waitForResults(_ summary: String, file: StaticString = #filePath, line: UInt = #line) {
        wait(for: app.descendants(matching: .any)["resultsSummary"], toSay: summary, file: file, line: line)
    }

    /// Waits until the pin page of `name` is on screen.
    func waitForPin(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        wait(for: pinTitle, toSay: name, file: file, line: line)
    }

    /// Waits until the tab's pin list reports `summary`, such as "ピン 3個".
    func waitForPins(_ summary: String, file: StaticString = #filePath, line: UInt = #line) {
        wait(for: pinsSummary, toSay: summary, file: file, line: line)
    }

    /// Waits until the place page of `name` is on screen.
    func waitForPlace(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        wait(for: placeTitle, toSay: name, file: file, line: line)
    }

    /// Waits until the element's label is `label`.
    func wait(
        for element: XCUIElement,
        toSay label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: 5),
            .completed,
            "\(element) does not say \(label)",
            file: file,
            line: line
        )
    }
}
