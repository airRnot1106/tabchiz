import Foundation
import Testing

@testable import Tabchiz

struct BrowserHistoryTests {
    typealias Samples = SamplePlaces

    let supermarket = LoadedBrowser.supermarket
    let gym = LoadedBrowser.gym
    let southArea = LoadedBrowser.southArea
    let closeUp = LoadedBrowser.closeUp

    // MARK: History

    @Test func backFromAPlaceRestoresTheResultsPageAndItsCamera() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        try LoadedBrowser.load(&browser, gym, Samples.gyms, in: id)
        browser.setCamera(southArea, for: .tab(id))
        let results = try #require(browser.tab(id)?.current)

        browser.openPlace(Samples.nearGym.id, in: id)
        browser.setCamera(closeUp, for: .tab(id))

        #expect(browser.activeTab.viewedPlace == Samples.nearGym)
        #expect(browser.activeTab.places == Samples.gyms)
        #expect(browser.activeTab.current.camera == closeUp)
        #expect(browser.activeTab.canGoBack)

        browser.back(in: id)

        #expect(browser.activeTab.current == results)
        #expect(browser.activeTab.current.camera == southArea)
        #expect(!browser.activeTab.canGoBack)
    }

    @Test func openingASiblingFromAPlacePageKeepsOneStepBackToTheResults() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        try LoadedBrowser.load(&browser, gym, Samples.gyms, in: id)
        browser.openPlace(Samples.nearGym.id, in: id)

        browser.openPlace(Samples.southGym.id, in: id)

        #expect(browser.activeTab.viewedPlace == Samples.southGym)
        #expect(browser.activeTab.backStack.count == 1)
    }

    @Test func aPlaceThatIsNotOnTheMapCannotBeOpened() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        try LoadedBrowser.load(&browser, gym, Samples.gyms, in: id)
        let before = browser

        browser.openPlace(Samples.cafeA.id, in: id)

        #expect(browser == before)
    }

    @Test func aNewQueryKeepsThePreviousResultsInTheHistory() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        try LoadedBrowser.load(&browser, supermarket, [Samples.market], in: id)
        browser.setCamera(southArea, for: .tab(id))

        browser.submit(gym, in: id)
        browser.setCamera(closeUp, for: .tab(id))

        #expect(browser.activeTab.current.page == .results(Search(query: gym, region: southArea), .idle))

        browser.back(in: id)

        #expect(browser.activeTab.query == supermarket)
        #expect(browser.activeTab.places == [Samples.market])
        #expect(browser.activeTab.current.camera == southArea)
    }

    @Test func theFirstQueryOfABlankTabLeavesNothingToGoBackTo() {
        var browser = Browser()
        let id = browser.activeTab.id

        browser.submit(gym, in: id)

        #expect(!browser.activeTab.canGoBack)
    }

    @Test func searchingHereAsksTheSameQueryForTheAreaOnTheMap() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        try LoadedBrowser.load(&browser, gym, Samples.gyms, in: id)
        browser.setCamera(southArea, for: .tab(id))

        browser.searchHere(in: id)

        #expect(browser.activeTab.current.page == .results(Search(query: gym, region: southArea), .idle))
        #expect(!browser.activeTab.canGoBack)
    }

    @Test func lateResultsForAReplacedQueryAreIgnored() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        browser.submit(supermarket, in: id)
        let replaced = try #require(browser.tab(id)?.current.page.search)
        browser.submit(gym, in: id)
        let before = browser

        browser.applySearch(.loaded([Samples.market]), for: replaced, in: id)

        #expect(browser == before)
        #expect(browser.activeTab.query == gym)
        #expect(browser.activeTab.places.isEmpty)
    }

    @Test func lateResultsForASearchedAreaTheTabHasLeftAreIgnored() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        browser.submit(gym, in: id)
        let replaced = try #require(browser.tab(id)?.current.page.search)
        browser.setCamera(southArea, for: .tab(id))
        browser.searchHere(in: id)

        browser.applySearch(.loaded(Samples.gyms), for: replaced, in: id)

        #expect(browser.activeTab.places.isEmpty)
    }

    // MARK: Jumps

    @Test func jumpingFromTheOverviewShowsThePlaceInItsTabAndBackReturnsToTheResults() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let gyms = loaded.gyms
        let results = try #require(browser.tab(gyms)?.current)
        browser.showOverview()

        browser.jump(to: Samples.nearGym.id, in: gyms)
        browser.setCamera(closeUp, for: .tab(gyms))

        #expect(browser.mode == .tab(gyms))
        #expect(browser.activeTab.viewedPlace == Samples.nearGym)

        browser.back(in: gyms)

        #expect(browser.mode == .tab(gyms))
        #expect(browser.activeTab.current == results)
    }

    @Test func jumpingToAPlaceTheTabDoesNotShowStaysInTheOverview() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let supermarkets = loaded.supermarkets
        browser.showOverview()
        let before = browser

        browser.jump(to: Samples.nearGym.id, in: supermarkets)

        #expect(browser == before)
    }

    @Test func jumpingToAClusterShowsTheTabsResultsAndBackReturnsToThePlace() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let gyms = loaded.gyms
        browser.openPlace(Samples.southGym.id, in: gyms)
        browser.showOverview()

        browser.jumpToResults(in: gyms)

        #expect(browser.mode == .tab(gyms))
        #expect(browser.activeTab.viewedPlace == nil)
        #expect(browser.activeTab.places == Samples.gyms)

        browser.back(in: gyms)

        #expect(browser.activeTab.viewedPlace == Samples.southGym)
    }

    // MARK: Nearest

    @Test func aPlacePageHasTheNearestPlaceOfEveryOtherTabWithResults() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let supermarkets = loaded.supermarkets
        let gyms = loaded.gyms
        browser.addTab()

        browser.openPlace(Samples.market.id, in: supermarkets)
        let nearest = browser.nearestToViewedSpot(in: supermarkets)

        #expect(nearest.map(\.tabID) == [gyms])
        #expect(nearest.first?.spot == .place(Samples.nearGym))
        #expect(abs((nearest.first?.distance ?? 0) - 133.43) < 1)
        #expect(browser.nearestToViewedSpot(in: gyms).isEmpty)
    }

    @Test func aPinPageHasTheNearestSpotOfEveryOtherTab() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let added = browser.addTab()
        let apartments = try #require(added)
        let pin = try browser.droppedPin(at: Samples.market.coordinate, in: apartments)

        browser.openPin(PinRef(tabID: apartments, pinID: pin.id))
        let nearest = browser.nearestToViewedSpot(in: apartments)

        #expect(nearest.map(\.tabID) == [loaded.supermarkets, loaded.gyms])
        #expect(nearest.map(\.spot) == [.place(Samples.market), .place(Samples.nearGym)])
        #expect(abs(nearest[0].distance) < 0.01)
        #expect(abs(nearest[1].distance - 133.43) < 1)
    }

    @Test func aPinSelectedInTheOverviewHasTheNearestSpotOfEveryOtherTab() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let pin = try browser.droppedPin(at: Samples.market.coordinate, in: loaded.supermarkets)
        browser.showOverview()
        #expect(browser.nearestToSelectedPin().isEmpty)

        browser.selectPinInOverview(PinRef(tabID: loaded.supermarkets, pinID: pin.id))
        let nearest = browser.nearestToSelectedPin()

        #expect(nearest.map(\.tabID) == [loaded.gyms])
        #expect(nearest.first?.spot == .place(Samples.nearGym))
        #expect(abs((nearest.first?.distance ?? 0) - 133.43) < 1)
    }

    @Test func launchingCentersEveryTabOnTheUserAndKeepsItsZoom() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let gyms = loaded.gyms
        browser.setCamera(closeUp, for: .tab(gyms))
        let user = Coordinate(latitude: 35.7, longitude: 139.71)

        browser.recenter(on: user)

        #expect(browser.tabs.map(\.current.camera.center) == [user, user])
        #expect(browser.tab(gyms)?.current.camera.latitudeDelta == closeUp.latitudeDelta)
    }
}
