import Foundation
import Testing

@testable import Tabchiz

@MainActor
struct BrowserStoreCameraTests {
    typealias Samples = SamplePlaces

    let southArea = LoadedBrowser.southArea
    let searcher = StubSearcher(results: [
        "スーパー": [Samples.market], "ジム": Samples.gyms,
    ])

    /// A store with a loaded スーパー tab and a loaded ジム tab, showing the ジム tab.
    private func storeWithTwoTabs() async throws -> (store: BrowserStore, gyms: TabID) {
        let store = BrowserStore(searcher: searcher, namer: StubNamer(), storage: MemoryStorage())
        store.submit(LoadedBrowser.supermarket, in: store.browser.activeTab.id)
        let gyms = try #require(store.addTab())
        store.submit(LoadedBrowser.gym, in: gyms)
        await store.waitForSearches()
        return (store, gyms)
    }

    @Test func openingAPlaceFramesItWithTheNearestPlaceOfEachOtherTab() async throws {
        let (store, gyms) = try await storeWithTwoTabs()
        let supermarkets = store.browser.tabs[0].id
        store.showTab(supermarkets)

        store.openPlace(Samples.market.id, in: supermarkets)

        #expect(store.browser.activeTab.viewedPlace == Samples.market)
        #expect(
            store.cameraCommand?.target
                == .fit([Samples.market.coordinate, Samples.nearGym.coordinate])
        )
        #expect(store.browser.nearestToViewedSpot(in: supermarkets).map(\.tabID) == [gyms])
    }

    @Test func goingBackMovesTheMapToThePreviousPagesCamera() async throws {
        let (store, gyms) = try await storeWithTwoTabs()
        store.cameraDidChange(southArea, in: .tab(gyms))
        store.openPlace(Samples.southGym.id, in: gyms)
        store.cameraDidChange(LoadedBrowser.closeUp, in: .tab(gyms))

        store.back(in: gyms)

        #expect(store.browser.activeTab.viewedPlace == nil)
        #expect(store.cameraCommand?.target == .region(southArea))
    }

    @Test func switchingTabsLeavesTheCameraToTheNewTabsOwnMap() async throws {
        let (store, gyms) = try await storeWithTwoTabs()
        store.cameraDidChange(southArea, in: .tab(gyms))
        let before = store.cameraCommand

        store.showTab(store.browser.tabs[0].id)

        #expect(store.cameraCommand == before)
        #expect(store.browser.activeTab.current.camera == .defaultArea)
        #expect(store.browser.tab(gyms)?.current.camera == southArea)
    }

    @Test func theOverviewFramesEveryPlaceUntilItHasACameraOfItsOwn() async throws {
        let (store, _) = try await storeWithTwoTabs()

        store.toggleOverview()

        let everyPlace = ([Samples.market] + Samples.gyms).map(\.coordinate)
        #expect(store.cameraCommand?.target == .fit(everyPlace))

        store.cameraDidChange(southArea, in: .overview)
        store.toggleOverview()
        let before = store.cameraCommand
        store.toggleOverview()

        #expect(store.browser.mode == .overview(returnTo: store.browser.tabs[1].id))
        #expect(store.cameraCommand == before)
    }

    @Test func jumpingFromTheOverviewShowsThePlaceInItsTabAndFramesIt() async throws {
        let (store, gyms) = try await storeWithTwoTabs()
        store.showTab(store.browser.tabs[0].id)
        store.toggleOverview()

        store.jump(to: Samples.nearGym.id, in: gyms)

        #expect(store.browser.mode == .tab(gyms))
        #expect(store.browser.activeTab.viewedPlace == Samples.nearGym)
        #expect(
            store.cameraCommand?.target
                == .fit([Samples.nearGym.coordinate, Samples.market.coordinate])
        )
    }

    @Test func jumpingToAClusterShowsTheTabsResultsWithTheMapOnTheCluster() async throws {
        let (store, gyms) = try await storeWithTwoTabs()
        store.toggleOverview()
        let cluster = [Samples.nextGym.coordinate, Samples.nearGym.coordinate]

        store.jumpToResults(framing: cluster, in: gyms)

        #expect(store.browser.mode == .tab(gyms))
        #expect(store.browser.activeTab.places == Samples.gyms)
        #expect(store.cameraCommand?.target == .fit(cluster))
    }
}
