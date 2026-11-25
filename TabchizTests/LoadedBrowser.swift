import Foundation
import Testing

@testable import Tabchiz

/// A browser with a スーパー tab and a ジム tab, both loaded, showing the スーパー tab.
struct LoadedBrowser {
    typealias Samples = SamplePlaces

    static let supermarket = SearchQuery(text: "スーパー")
    static let gym = SearchQuery(text: "ジム")
    static let southArea = CameraRegion(
        center: Coordinate(latitude: 35.6674, longitude: 139.7234),
        latitudeDelta: 0.01,
        longitudeDelta: 0.01
    )
    static let closeUp = CameraRegion(
        center: Samples.nearGym.coordinate,
        latitudeDelta: 0.002,
        longitudeDelta: 0.002
    )

    var browser: Browser
    let supermarkets: TabID
    let gyms: TabID

    init() throws {
        var browser = Browser()
        supermarkets = browser.activeTab.id
        try Self.load(&browser, Self.supermarket, [Samples.market], in: supermarkets)
        let added = browser.addTab()
        gyms = try #require(added)
        try Self.load(&browser, Self.gym, Samples.gyms, in: gyms)
        browser.showTab(supermarkets)
        self.browser = browser
    }

    /// Submits the query in the tab and loads `places` as its results.
    static func load(_ browser: inout Browser, _ query: SearchQuery, _ places: [Place], in id: TabID) throws {
        browser.submit(query, in: id)
        let search = try #require(browser.tab(id)?.current.page.search)
        browser.applySearch(.loaded(places), for: search, in: id)
    }
}

extension Browser {
    /// Drops a pin in the tab and returns it.
    mutating func droppedPin(at coordinate: Coordinate, in id: TabID) throws -> Pin {
        let pin = dropPin(at: coordinate, in: id)
        return try #require(pin)
    }

    /// Pins a place the tab shows and returns the pin.
    mutating func pinnedPlace(_ placeID: PlaceID, in id: TabID) throws -> Pin {
        let pin = pinPlace(placeID, in: id)
        return try #require(pin)
    }
}
