import Foundation
import Testing

@testable import Tabchiz

struct BrowserPinsTests {
    typealias Samples = SamplePlaces

    let west = Coordinate(latitude: 35.6749, longitude: 139.7164)
    let east = Coordinate(latitude: 35.6764, longitude: 139.7274)
    let south = Coordinate(latitude: 35.6694, longitude: 139.7224)

    // MARK: Dropping

    @Test func droppedPinsKeepTheirOrderAndAreNumbered() throws {
        var browser = Browser()
        let id = browser.activeTab.id

        browser.dropPin(at: west, in: id)
        browser.dropPin(at: east, in: id)
        browser.dropPin(at: south, in: id)

        let pins = browser.activeTab.pins
        #expect(pins.map(\.name) == ["ピン 1", "ピン 2", "ピン 3"])
        #expect(pins.map(\.coordinate) == [west, east, south])
        #expect(pins.allSatisfy { $0.origin == .dropped })
        #expect(Set(pins.map(\.id)).count == 3)
    }

    @Test func aDroppedPinTakesTheLowestNumberNoPinOfTheTabUses() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        let first = try browser.droppedPin(at: west, in: id)
        browser.dropPin(at: east, in: id)
        browser.removePin(PinRef(tabID: id, pinID: first.id))

        browser.dropPin(at: south, in: id)

        #expect(browser.activeTab.pins.map(\.name) == ["ピン 2", "ピン 1"])
    }

    @Test func aBlankTabHoldsPinsAndStaysBlank() {
        var browser = Browser()
        let id = browser.activeTab.id

        browser.dropPin(at: west, in: id)

        #expect(browser.activeTab.current.page == .blank)
        #expect(!browser.activeTab.canGoBack)
        #expect(browser.activeTab.pins.count == 1)
    }

    @Test func droppingAPinInATabThatDoesNotExistChangesNothing() {
        var browser = Browser()
        let before = browser

        #expect(browser.dropPin(at: west, in: TabID()) == nil)
        #expect(browser == before)
    }

    @Test func eachTabHasItsOwnPins() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser

        browser.dropPin(at: west, in: loaded.gyms)

        #expect(browser.tab(loaded.gyms)?.pins.count == 1)
        #expect(browser.tab(loaded.supermarkets)?.pins.isEmpty == true)
    }

    @Test func searchingOpeningAPlaceAndGoingBackKeepThePins() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        browser.dropPin(at: west, in: id)
        browser.dropPin(at: east, in: id)
        let pins = browser.activeTab.pins

        try LoadedBrowser.load(&browser, LoadedBrowser.gym, Samples.gyms, in: id)
        #expect(browser.activeTab.pins == pins)

        browser.openPlace(Samples.southGym.id, in: id)
        #expect(browser.activeTab.pins == pins)

        try LoadedBrowser.load(&browser, LoadedBrowser.supermarket, [Samples.market], in: id)
        browser.back(in: id)
        browser.back(in: id)
        #expect(browser.activeTab.pins == pins)
        #expect(browser.activeTab.places == Samples.gyms)
    }

    // MARK: Pinning a place

    @Test func pinningAPlaceUsesItsNameAndCoordinate() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser

        let pin = try browser.pinnedPlace(Samples.southGym.id, in: loaded.gyms)

        #expect(pin.name == Samples.southGym.name)
        #expect(pin.coordinate == Samples.southGym.coordinate)
        #expect(pin.origin == .place(Samples.southGym.id))
        #expect(browser.tab(loaded.gyms)?.pins == [pin])
        #expect(browser.tab(loaded.gyms)?.pin(for: Samples.southGym.id) == pin)
    }

    @Test func pinningTheSamePlaceTwiceInATabKeepsOnePin() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        browser.pinPlace(Samples.southGym.id, in: loaded.gyms)
        let before = browser

        #expect(browser.pinPlace(Samples.southGym.id, in: loaded.gyms) == nil)
        #expect(browser == before)
    }

    @Test func anotherTabCanPinTheSamePlace() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        try LoadedBrowser.load(&browser, LoadedBrowser.gym, Samples.gyms, in: loaded.supermarkets)

        browser.pinPlace(Samples.southGym.id, in: loaded.gyms)
        browser.pinPlace(Samples.southGym.id, in: loaded.supermarkets)

        #expect(browser.tabs.map(\.pins.count) == [1, 1])
        #expect(browser.tabs[0].pins[0].id != browser.tabs[1].pins[0].id)
    }

    @Test func pinningAPlaceTheTabDoesNotShowChangesNothing() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let before = browser

        #expect(browser.pinPlace(Samples.southGym.id, in: loaded.supermarkets) == nil)
        #expect(browser == before)
    }

    @Test func aPlaceCanBePinnedFromItsPlacePage() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        browser.openPlace(Samples.southGym.id, in: loaded.gyms)

        browser.pinPlace(Samples.nextGym.id, in: loaded.gyms)
        browser.pinPlace(Samples.southGym.id, in: loaded.gyms)

        #expect(browser.tab(loaded.gyms)?.pins.map(\.name) == [Samples.nextGym.name, Samples.southGym.name])
        #expect(browser.tab(loaded.gyms)?.viewedPlace == Samples.southGym)
    }

    @Test func aPinnedPlaceStaysPinnedAfterTheTabSearchesSomethingElse() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let pin = try browser.pinnedPlace(Samples.southGym.id, in: loaded.gyms)

        try LoadedBrowser.load(&browser, LoadedBrowser.supermarket, [Samples.market], in: loaded.gyms)

        #expect(browser.tab(loaded.gyms)?.pins == [pin])
    }

    // MARK: Renaming and removing

    @Test func renamingTrimsTheNameAndIgnoresABlankOne() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        let pin = try browser.droppedPin(at: west, in: id)
        let ref = PinRef(tabID: id, pinID: pin.id)

        browser.renamePin(ref, to: "  テスト住まい西 \n")
        #expect(browser.activeTab.pins.map(\.name) == ["テスト住まい西"])

        browser.renamePin(ref, to: "   ")
        #expect(browser.activeTab.pins.map(\.name) == ["テスト住まい西"])
        #expect(browser.activeTab.pins[0].id == pin.id)
        #expect(browser.activeTab.pins[0].coordinate == west)
    }

    @Test func anAddressThatArrivesLateDoesNotReplaceANameTheUserTyped() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        let named = try browser.droppedPin(at: west, in: id)
        let renamed = try browser.droppedPin(at: east, in: id)
        browser.renamePin(PinRef(tabID: id, pinID: renamed.id), to: "テスト住まい東")

        browser.renamePin(PinRef(tabID: id, pinID: named.id), to: "テスト町1丁目", ifStillNamed: named.name)
        browser.renamePin(PinRef(tabID: id, pinID: renamed.id), to: "テスト町5丁目", ifStillNamed: renamed.name)

        #expect(browser.activeTab.pins.map(\.name) == ["テスト町1丁目", "テスト住まい東"])
    }

    @Test func removingAPinKeepsTheOthersInOrder() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        browser.dropPin(at: west, in: id)
        let middle = try browser.droppedPin(at: east, in: id)
        browser.dropPin(at: south, in: id)

        browser.removePin(PinRef(tabID: id, pinID: middle.id))

        #expect(browser.activeTab.pins.map(\.coordinate) == [west, south])
    }

    @Test func removingAPinThatDoesNotExistChangesNothing() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        browser.dropPin(at: west, in: id)
        browser.showOverview()
        browser.setCamera(LoadedBrowser.southArea, for: .overview)
        let before = browser

        browser.removePin(PinRef(tabID: id, pinID: PinID()))

        #expect(browser == before)
    }

    @Test func removingATabRemovesItsPins() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        browser.dropPin(at: west, in: loaded.gyms)
        browser.dropPin(at: east, in: loaded.supermarkets)

        browser.removeTab(loaded.gyms)

        #expect(browser.tabs.map(\.id) == [loaded.supermarkets])
        #expect(browser.tabs.flatMap(\.pins).map(\.coordinate) == [east])
    }

    @Test func pinsAddedOrRemovedMakeTheOverviewFrameEverythingAgain() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        browser.showOverview()
        browser.setCamera(LoadedBrowser.southArea, for: .overview)
        browser.leaveOverview()

        let pin = try browser.droppedPin(at: west, in: loaded.gyms)
        #expect(browser.overviewCamera == nil)

        browser.setCamera(LoadedBrowser.southArea, for: .overview)
        browser.renamePin(PinRef(tabID: loaded.gyms, pinID: pin.id), to: "テスト住まい西")
        #expect(browser.overviewCamera == LoadedBrowser.southArea)

        browser.removePin(PinRef(tabID: loaded.gyms, pinID: pin.id))
        #expect(browser.overviewCamera == nil)
    }
}
