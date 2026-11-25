import Foundation
import Testing

@testable import Tabchiz

struct BrowserPinPagesTests {
    typealias Samples = SamplePlaces

    let west = Coordinate(latitude: 35.6749, longitude: 139.7164)
    let east = Coordinate(latitude: 35.6764, longitude: 139.7274)

    /// A browser whose only tab is blank and holds one pin.
    private func pinned() throws -> (browser: Browser, ref: PinRef) {
        var browser = Browser()
        let id = browser.activeTab.id
        let pin = try browser.droppedPin(at: west, in: id)
        return (browser, PinRef(tabID: id, pinID: pin.id))
    }

    // MARK: Pin page

    @Test func openingAPinFromABlankTabShowsItsPageAndBackReturnsToTheBlankPage() throws {
        var (browser, ref) = try pinned()

        browser.openPin(ref)

        #expect(browser.activeTab.viewedPin?.id == ref.pinID)
        #expect(browser.activeTab.viewedSpot == browser.activeTab.pins.first.map(Spot.pin))
        #expect(browser.activeTab.canGoBack)
        #expect(browser.activeTab.query == nil)

        browser.back(in: ref.tabID)

        #expect(browser.activeTab.current.page == .blank)
        #expect(!browser.activeTab.canGoBack)
        #expect(browser.activeTab.pins.count == 1)
    }

    @Test func aPinPageKeepsTheResultsOnTheMapAndBackRestoresTheResultsPageAndItsCamera() throws {
        var (browser, ref) = try pinned()
        try LoadedBrowser.load(&browser, LoadedBrowser.gym, Samples.gyms, in: ref.tabID)
        browser.setCamera(LoadedBrowser.southArea, for: .tab(ref.tabID))
        let results = try #require(browser.tab(ref.tabID)?.current)

        browser.openPin(ref)
        browser.setCamera(LoadedBrowser.closeUp, for: .tab(ref.tabID))

        #expect(browser.activeTab.viewedPin?.id == ref.pinID)
        #expect(browser.activeTab.viewedPlace == nil)
        #expect(browser.activeTab.places == Samples.gyms)
        #expect(browser.activeTab.query == LoadedBrowser.gym)

        browser.back(in: ref.tabID)

        #expect(browser.activeTab.current == results)
    }

    @Test func resultsThatArriveWhileAPinPageIsShownGoOnItsMapAndStayAfterBack() throws {
        var (browser, ref) = try pinned()
        browser.submit(LoadedBrowser.gym, in: ref.tabID)
        let search = try #require(browser.tab(ref.tabID)?.current.page.search)
        browser.openPin(ref)

        browser.applySearch(.loaded(Samples.gyms), for: search, in: ref.tabID)

        #expect(browser.activeTab.viewedPin?.id == ref.pinID)
        #expect(browser.activeTab.places == Samples.gyms)

        browser.back(in: ref.tabID)

        #expect(browser.activeTab.current.page == .results(search, .loaded(Samples.gyms)))
    }

    @Test func aPinPageIgnoresResultsOfASearchItIsNotOver() throws {
        var (browser, ref) = try pinned()
        browser.submit(LoadedBrowser.gym, in: ref.tabID)
        let stale = try #require(browser.tab(ref.tabID)?.current.page.search)
        browser.submit(LoadedBrowser.supermarket, in: ref.tabID)
        browser.openPin(ref)

        browser.applySearch(.loaded(Samples.gyms), for: stale, in: ref.tabID)

        #expect(browser.activeTab.places.isEmpty)
    }

    @Test func openingAnotherPinReplacesThePinPageSoBackLeavesThePins() throws {
        var (browser, ref) = try pinned()
        let second = try browser.droppedPin(at: east, in: ref.tabID)
        browser.openPin(ref)

        browser.openPin(PinRef(tabID: ref.tabID, pinID: second.id))

        #expect(browser.activeTab.viewedPin?.id == second.id)
        #expect(browser.activeTab.backStack.count == 1)

        browser.back(in: ref.tabID)

        #expect(browser.activeTab.current.page == .blank)
    }

    @Test func openingThePinThatIsAlreadyShownChangesNothing() throws {
        var (browser, ref) = try pinned()
        browser.openPin(ref)
        let before = browser

        browser.openPin(ref)

        #expect(browser == before)
    }

    @Test func openingAPinThatDoesNotExistChangesNothing() throws {
        var (browser, ref) = try pinned()
        let before = browser

        browser.openPin(PinRef(tabID: ref.tabID, pinID: PinID()))
        browser.openPin(PinRef(tabID: TabID(), pinID: ref.pinID))

        #expect(browser == before)
    }

    @Test func removingTheViewedPinGoesBack() throws {
        var (browser, ref) = try pinned()
        try LoadedBrowser.load(&browser, LoadedBrowser.gym, Samples.gyms, in: ref.tabID)
        let results = try #require(browser.tab(ref.tabID)?.current)
        browser.openPin(ref)

        browser.removePin(ref)

        #expect(browser.activeTab.current == results)
        #expect(browser.activeTab.viewedPin == nil)
        #expect(browser.activeTab.pins.isEmpty)
        #expect(!browser.activeTab.canGoBack)
    }

    @Test func removingAPinDropsItsPagesFromTheHistory() throws {
        var (browser, ref) = try pinned()
        browser.openPin(ref)
        try LoadedBrowser.load(&browser, LoadedBrowser.gym, Samples.gyms, in: ref.tabID)
        browser.openPin(ref)
        try LoadedBrowser.load(&browser, LoadedBrowser.supermarket, [Samples.market], in: ref.tabID)

        browser.removePin(ref)

        #expect(browser.activeTab.query == LoadedBrowser.supermarket)
        let history = browser.activeTab.backStack.map(\.page) + [browser.activeTab.current.page]
        #expect(history.allSatisfy { $0.pinID == nil })

        browser.back(in: ref.tabID)
        #expect(browser.activeTab.places == Samples.gyms)

        browser.back(in: ref.tabID)
        #expect(browser.activeTab.current.page == .blank)
        #expect(!browser.activeTab.canGoBack)
    }

    @Test func aPlaceOpenedFromAPinPageReturnsToThePinPage() throws {
        var (browser, ref) = try pinned()
        try LoadedBrowser.load(&browser, LoadedBrowser.gym, Samples.gyms, in: ref.tabID)
        browser.openPin(ref)

        browser.openPlace(Samples.southGym.id, in: ref.tabID)

        #expect(browser.activeTab.viewedPlace == Samples.southGym)
        #expect(browser.activeTab.viewedPin == nil)

        browser.back(in: ref.tabID)

        #expect(browser.activeTab.viewedPin?.id == ref.pinID)
    }

    @Test func aSearchFromAPinPageKeepsThePinPageInTheHistory() throws {
        var (browser, ref) = try pinned()
        browser.openPin(ref)

        try LoadedBrowser.load(&browser, LoadedBrowser.gym, Samples.gyms, in: ref.tabID)

        #expect(browser.activeTab.viewedPin == nil)
        #expect(browser.activeTab.places == Samples.gyms)

        browser.back(in: ref.tabID)

        #expect(browser.activeTab.viewedPin?.id == ref.pinID)
        #expect(browser.activeTab.places.isEmpty)
    }

    @Test func aRenamedPinShowsItsNewNameOnItsPage() throws {
        var (browser, ref) = try pinned()
        browser.openPin(ref)

        browser.renamePin(ref, to: "テスト住まい西")

        #expect(browser.activeTab.viewedPin?.name == "テスト住まい西")
    }

    @Test func openingAPinOfAnotherTabSwitchesToThatTab() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let pin = try browser.droppedPin(at: west, in: loaded.gyms)

        browser.openPin(PinRef(tabID: loaded.gyms, pinID: pin.id))

        #expect(browser.mode == .tab(loaded.gyms))
        #expect(browser.activeTab.viewedPin == pin)
        #expect(browser.activeTab.places == Samples.gyms)
    }

    @Test func jumpingToAClusterFromAPinPageShowsTheResultsAndBackReturnsToThePin() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let pin = try browser.droppedPin(at: west, in: loaded.gyms)
        browser.openPin(PinRef(tabID: loaded.gyms, pinID: pin.id))
        browser.showOverview()

        browser.jumpToResults(in: loaded.gyms)

        #expect(browser.mode == .tab(loaded.gyms))
        #expect(browser.activeTab.viewedPin == nil)
        #expect(browser.activeTab.places == Samples.gyms)

        browser.back(in: loaded.gyms)

        #expect(browser.activeTab.viewedPin == pin)
    }

    // MARK: Overview selection

    @Test func selectingAPinInTheOverviewStaysInTheOverview() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let pin = try browser.droppedPin(at: west, in: loaded.gyms)
        let ref = PinRef(tabID: loaded.gyms, pinID: pin.id)
        browser.showOverview()

        browser.selectPinInOverview(ref)

        #expect(browser.mode == .overview(returnTo: loaded.supermarkets, selected: ref))
        #expect(browser.mode.scene == .overview)
        #expect(browser.selectedPin?.pin == pin)
        #expect(browser.selectedPin?.tab.id == loaded.gyms)
        #expect(browser.tab(loaded.gyms)?.viewedPin == nil)

        browser.selectPinInOverview(nil)

        #expect(browser.mode == .overview(returnTo: loaded.supermarkets))
        #expect(browser.selectedPin == nil)
    }

    @Test func aPinCanOnlyBeSelectedInTheOverviewAndOnlyWhenItExists() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let pin = try browser.droppedPin(at: west, in: loaded.gyms)
        let ref = PinRef(tabID: loaded.gyms, pinID: pin.id)

        browser.selectPinInOverview(ref)
        #expect(browser.mode == .tab(loaded.supermarkets))

        browser.showOverview()
        browser.selectPinInOverview(PinRef(tabID: loaded.supermarkets, pinID: pin.id))
        browser.selectPinInOverview(PinRef(tabID: loaded.gyms, pinID: PinID()))
        #expect(browser.mode == .overview(returnTo: loaded.supermarkets))
    }

    @Test func leavingTheOverviewClearsTheSelection() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let pin = try browser.droppedPin(at: west, in: loaded.gyms)
        browser.showOverview()
        browser.selectPinInOverview(PinRef(tabID: loaded.gyms, pinID: pin.id))

        browser.leaveOverview()
        #expect(browser.mode == .tab(loaded.supermarkets))

        browser.showOverview()
        #expect(browser.selectedPin == nil)
    }

    @Test func removingTheSelectedPinOrItsTabClearsTheSelection() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let pin = try browser.droppedPin(at: west, in: loaded.gyms)
        let ref = PinRef(tabID: loaded.gyms, pinID: pin.id)
        browser.showOverview()
        browser.selectPinInOverview(ref)
        var closed = browser

        browser.removePin(ref)
        #expect(browser.mode == .overview(returnTo: loaded.supermarkets))

        closed.removeTab(loaded.gyms)
        #expect(closed.mode == .overview(returnTo: loaded.supermarkets))
    }

    @Test func removingAnotherPinOrAnotherTabKeepsTheSelection() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let pin = try browser.droppedPin(at: west, in: loaded.gyms)
        let other = try browser.droppedPin(at: east, in: loaded.gyms)
        let ref = PinRef(tabID: loaded.gyms, pinID: pin.id)
        browser.showOverview()
        browser.selectPinInOverview(ref)

        browser.removePin(PinRef(tabID: loaded.gyms, pinID: other.id))
        #expect(browser.mode == .overview(returnTo: loaded.supermarkets, selected: ref))

        browser.removeTab(loaded.supermarkets)
        #expect(browser.mode == .overview(returnTo: loaded.gyms, selected: ref))
    }

    @Test func openingTheSelectedPinLeavesTheOverviewForItsTab() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let pin = try browser.droppedPin(at: west, in: loaded.gyms)
        let ref = PinRef(tabID: loaded.gyms, pinID: pin.id)
        browser.showOverview()
        browser.selectPinInOverview(ref)

        browser.openPin(ref)

        #expect(browser.mode == .tab(loaded.gyms))
        #expect(browser.activeTab.viewedPin == pin)
    }
}
