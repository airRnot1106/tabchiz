import Foundation
import Testing

@testable import Tabchiz

struct BrowserTabsTests {
    typealias Samples = SamplePlaces

    let supermarket = LoadedBrowser.supermarket
    let gym = LoadedBrowser.gym
    let southArea = LoadedBrowser.southArea
    let closeUp = LoadedBrowser.closeUp

    // MARK: Tabs

    @Test func aNewBrowserShowsOneBlankTab() {
        let browser = Browser()

        #expect(browser.tabs.count == 1)
        #expect(browser.activeTab.current.page == .blank)
        #expect(browser.mode == .tab(browser.tabs[0].id))
    }

    @Test func aNewTabIsBlankShowsTheSameAreaAndComesToTheFront() throws {
        var browser = Browser()
        browser.setCamera(southArea, for: .tab(browser.activeTab.id))

        let added = browser.addTab()
        let id = try #require(added)

        #expect(browser.mode == .tab(id))
        #expect(browser.activeTab.current == Entry(page: .blank, camera: southArea))
        #expect(browser.tabs.map(\.color) == [.orange, .skyBlue])
    }

    @Test func sixthTabIsRejected() {
        var browser = Browser()
        for _ in 1..<Browser.maxTabs {
            #expect(browser.addTab() != nil)
        }
        let front = browser.mode

        #expect(!browser.canAddTab)
        #expect(browser.addTab() == nil)
        #expect(browser.tabs.count == 5)
        #expect(browser.tabs.map(\.color) == TabColor.allCases)
        #expect(browser.mode == front)
    }

    @Test func removedTabsColorGoesToTheNextNewTab() {
        var browser = Browser()
        let first = browser.activeTab.id
        browser.addTab()

        browser.removeTab(first)
        browser.addTab()

        #expect(browser.tabs.map(\.color) == [.skyBlue, .orange])
    }

    @Test func removingTheTabOnScreenShowsItsRightNeighbor() throws {
        var browser = Browser()
        browser.addTab()
        let middle = browser.activeTab.id
        let added = browser.addTab()
        let last = try #require(added)
        browser.showTab(middle)

        browser.removeTab(middle)

        #expect(browser.mode == .tab(last))
        #expect(browser.tabs.count == 2)
    }

    @Test func removingTheLastTabOnScreenShowsItsLeftNeighbor() throws {
        var browser = Browser()
        let first = browser.activeTab.id
        let added = browser.addTab()
        let last = try #require(added)

        browser.removeTab(last)

        #expect(browser.mode == .tab(first))
    }

    @Test func removingATabInTheBackgroundKeepsTheTabOnScreen() throws {
        var browser = Browser()
        let first = browser.activeTab.id
        let added = browser.addTab()
        let second = try #require(added)

        browser.removeTab(first)

        #expect(browser.mode == .tab(second))
        #expect(browser.tabs.map(\.id) == [second])
    }

    @Test func removingTheOnlyTabLeavesABlankTabOnTheSameArea() throws {
        var browser = Browser()
        let only = browser.activeTab.id
        try LoadedBrowser.load(&browser, gym, Samples.gyms, in: only)
        browser.setCamera(southArea, for: .tab(only))

        browser.removeTab(only)

        #expect(browser.tabs.count == 1)
        #expect(browser.activeTab.id != only)
        #expect(browser.activeTab.current == Entry(page: .blank, camera: southArea))
        #expect(browser.mode == .tab(browser.activeTab.id))
    }

    @Test func removingTheTabTheOverviewReturnsToPicksItsNeighbor() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let supermarkets = loaded.supermarkets
        let gyms = loaded.gyms
        browser.showOverview()

        browser.removeTab(supermarkets)

        #expect(browser.mode == .overview(returnTo: gyms))
    }

    // MARK: Switching

    @Test func switchingTabsKeepsEachTabsCameraAndPage() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let supermarkets = loaded.supermarkets
        let gyms = loaded.gyms
        browser.setCamera(southArea, for: .tab(supermarkets))
        browser.showTab(gyms)
        browser.setCamera(closeUp, for: .tab(gyms))
        browser.openPlace(Samples.southGym.id, in: gyms)

        browser.showTab(supermarkets)

        #expect(browser.mode == .tab(supermarkets))
        #expect(browser.activeTab.current.camera == southArea)
        #expect(browser.activeTab.places == [Samples.market])
        #expect(browser.activeTab.viewedPlace == nil)

        browser.showTab(gyms)

        #expect(browser.activeTab.current.camera == closeUp)
        #expect(browser.activeTab.viewedPlace == Samples.southGym)
    }

    @Test func theOverviewRemembersTheTabItWasEnteredFromAndItsOwnCamera() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let supermarkets = loaded.supermarkets
        let gyms = loaded.gyms
        browser.showTab(gyms)

        browser.showOverview()
        browser.setCamera(southArea, for: .overview)

        #expect(browser.mode == .overview(returnTo: gyms))
        #expect(browser.tab(gyms)?.current.camera == .defaultArea)

        browser.leaveOverview()

        #expect(browser.mode == .tab(gyms))

        browser.showTab(supermarkets)
        browser.showOverview()

        #expect(browser.mode == .overview(returnTo: supermarkets))
        #expect(browser.overviewCamera == southArea)
    }

    @Test func newResultsMakeTheOverviewFrameEveryPlaceAgain() throws {
        let loaded = try LoadedBrowser()
        var browser = loaded.browser
        let supermarkets = loaded.supermarkets
        browser.showOverview()
        browser.setCamera(southArea, for: .overview)

        try LoadedBrowser.load(&browser, SearchQuery(text: "カフェ"), Samples.cafes, in: supermarkets)

        #expect(browser.overviewCamera == nil)
    }
}
