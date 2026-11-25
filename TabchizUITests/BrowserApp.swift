import XCTest

/// The app launched on the bundled invented places, with the elements the tests drive.
@MainActor
struct BrowserApp {
    let app: XCUIApplication

    /// Launches with empty saved tabs, or with one tab per query.
    static func launch(seeding queries: [String] = []) -> Self {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFixture"]
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

    /// Waits until the place page of `name` is on screen.
    func waitForPlace(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        wait(for: placeTitle, toSay: name, file: file, line: line)
    }

    private func wait(for element: XCUIElement, toSay label: String, file: StaticString, line: UInt) {
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
