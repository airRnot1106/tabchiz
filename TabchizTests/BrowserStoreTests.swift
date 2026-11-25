import Foundation
import MapKit
import Synchronization
import Testing

@testable import Tabchiz

@MainActor
struct BrowserStoreTests {
    typealias Samples = SamplePlaces

    let supermarket = SearchQuery(text: "スーパー")
    let gym = SearchQuery(text: "ジム")
    let southArea = LoadedBrowser.southArea
    let searcher = StubSearcher(results: [
        "スーパー": [Samples.market], "ジム": Samples.gyms, "カフェ": Samples.cafes,
    ])

    // MARK: Searching

    @Test func submittingAQuerySearchesTheAreaOfThatTabsMap() async {
        let store = BrowserStore(searcher: searcher, storage: MemoryStorage())
        let id = store.browser.activeTab.id
        store.cameraDidChange(southArea, in: .tab(id))

        store.submit(gym, in: id)
        await store.waitForSearches()

        #expect(
            store.browser.activeTab.current.page
                == .results(Search(query: gym, region: southArea), .loaded(Samples.gyms)))
        #expect(searcher.regions == [southArea])
    }

    @Test func eachTabSearchesItsOwnArea() async throws {
        let store = BrowserStore(searcher: searcher, storage: MemoryStorage())
        let first = store.browser.activeTab.id
        let second = try #require(store.addTab())
        store.cameraDidChange(southArea, in: .tab(second))

        store.submit(supermarket, in: first)
        store.submit(gym, in: second)
        await store.waitForSearches()

        #expect(store.browser.tab(first)?.current.page.search?.region == .defaultArea)
        #expect(store.browser.tab(second)?.current.page.search?.region == southArea)
        #expect(Set(searcher.regions) == [.defaultArea, southArea])
    }

    @Test func aReplacedQueryShowsOnlyTheNewQuerysResults() async throws {
        let slow = StubSearcher(
            results: ["スーパー": [Samples.market], "ジム": Samples.gyms],
            delays: ["スーパー": .milliseconds(300)]
        )
        let store = BrowserStore(searcher: slow, storage: MemoryStorage())
        let id = store.browser.activeTab.id
        store.submit(supermarket, in: id)

        store.submit(gym, in: id)
        await store.waitForSearches()
        try await Task.sleep(for: .milliseconds(400))

        #expect(store.browser.activeTab.query == gym)
        #expect(store.browser.activeTab.places == Samples.gyms)
    }

    @Test func goingBackToResultsThatNeverLoadedSearchesThemAgain() async {
        let slow = StubSearcher(
            results: ["スーパー": [Samples.market], "ジム": Samples.gyms],
            delays: ["スーパー": .milliseconds(100)]
        )
        let store = BrowserStore(searcher: slow, storage: MemoryStorage())
        let id = store.browser.activeTab.id
        store.submit(supermarket, in: id)
        store.submit(gym, in: id)
        await store.waitForSearches()

        store.back(in: id)
        await store.waitForSearches()

        #expect(store.browser.activeTab.query == supermarket)
        #expect(store.browser.activeTab.places == [Samples.market])
    }

    @Test func aRemovedTabsSearchResultIsDropped() async throws {
        let slow = StubSearcher(results: ["ジム": Samples.gyms], delays: ["ジム": .milliseconds(200)])
        let storage = MemoryStorage()
        let store = BrowserStore(searcher: slow, storage: storage)
        let first = store.browser.activeTab.id
        let second = try #require(store.addTab())
        store.submit(gym, in: second)

        store.removeTab(second)
        await store.waitForSearches()
        try await Task.sleep(for: .milliseconds(300))

        #expect(store.browser.tabs.map(\.id) == [first])
        #expect(store.browser.activeTab.current.page == .blank)
        #expect(storage.saved.map(\.text) == [nil])
    }

    @Test func exhaustedBudgetWaitsAndThenSearchesByItself() async throws {
        let store = BrowserStore(
            searcher: searcher,
            storage: MemoryStorage(),
            budget: RequestBudget(limit: 1, window: 0.3)
        )
        let first = store.browser.activeTab.id
        store.submit(supermarket, in: first)
        await store.waitForSearches()

        let second = try #require(store.addTab())
        store.submit(gym, in: second)
        try await Task.sleep(for: .milliseconds(50))
        let waiting = store.browser.tab(second)?.current.page
        let observedAt = Date()
        await store.waitForSearches()

        guard case .results(_, .throttled(let retryAt)) = waiting else {
            Issue.record("Expected the second tab to wait for the budget, got \(String(describing: waiting))")
            return
        }
        #expect(retryAt > observedAt)
        #expect(store.browser.tab(second)?.places == Samples.gyms)
    }

    @Test func mapKitThrottlingWaitsForTheBackoffBeforeRetrying() async throws {
        let throttling = StubSearcher(results: ["カフェ": Samples.cafes], throttledCalls: 1)
        let clock = Mutex(Date())
        let store = BrowserStore(searcher: throttling, storage: MemoryStorage(), now: { clock.withLock { $0 } })
        let start = clock.withLock { $0 }
        let id = store.browser.activeTab.id
        store.submit(SearchQuery(text: "カフェ"), in: id)
        try await Task.sleep(for: .milliseconds(50))

        guard case .results(_, let state) = store.browser.activeTab.current.page else {
            Issue.record("Expected a results page")
            return
        }
        #expect(state == .throttled(retryAt: start.addingTimeInterval(BrowserStore.mapKitThrottleBackoff)))

        store.removeTab(id)
        #expect(throttling.regions.count == 1)
    }

    @Test func theSearchHereButtonAppearsOnlyAfterTheTabsMapLeftTheSearchedArea() async {
        let store = BrowserStore(searcher: searcher, storage: MemoryStorage())
        let id = store.browser.activeTab.id
        #expect(!store.showsResearchButton)

        store.submit(gym, in: id)
        await store.waitForSearches()
        #expect(!store.showsResearchButton)

        store.cameraDidChange(southArea, in: .tab(id))
        #expect(store.showsResearchButton)

        store.searchHere(in: id)
        await store.waitForSearches()
        #expect(!store.showsResearchButton)
        #expect(searcher.regions == [.defaultArea, southArea])
    }

    // MARK: Saved tabs

    @Test func tabsAreSavedWithTheirQueryAndColor() async throws {
        let storage = MemoryStorage()
        let store = BrowserStore(searcher: searcher, storage: storage)
        store.submit(gym, in: store.browser.activeTab.id)
        store.addTab()

        #expect(storage.saved.map(\.text) == ["ジム", nil])
        #expect(storage.saved.map(\.color) == [.orange, .skyBlue])
        #expect(storage.saved.map(\.id) == store.browser.tabs.map(\.id.rawValue))
    }

    @Test func launchRestoresSavedTabsAndSearchesThemAgain() async {
        let storage = MemoryStorage([
            SavedTab(query: supermarket, color: .skyBlue),
            SavedTab(query: nil, color: .orange),
            SavedTab(query: gym, color: .vermillion),
        ])
        let store = BrowserStore(searcher: searcher, storage: storage)

        await store.launch()

        #expect(store.browser.tabs.map(\.id.rawValue) == storage.saved.map(\.id))
        #expect(store.browser.tabs.map(\.color) == [.skyBlue, .orange, .vermillion])
        #expect(store.browser.tabs.map(\.query) == [supermarket, nil, gym])
        #expect(store.browser.tabs.map(\.places) == [[Samples.market], [], Samples.gyms])
        #expect(store.browser.mode == .tab(store.browser.tabs[0].id))
    }

    @Test func launchSearchesAroundTheUser() async {
        let user = Coordinate(latitude: 35.7, longitude: 139.71)
        var around = CameraRegion.defaultArea
        around.center = user
        let storage = MemoryStorage([SavedTab(query: gym, color: .orange)])
        let store = BrowserStore(searcher: searcher, storage: storage, locate: { user })

        await store.launch()

        #expect(store.browser.activeTab.current.camera == around)
        #expect(store.cameraCommand?.target == .region(around))
        #expect(searcher.regions == [around])
    }

    @Test func tabsSavedByTheLayerVersionStillLoad() throws {
        let suite = "BrowserStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let layerVersion = """
            [{"id":"6F1B7C0E-6C0B-4F0A-9E57-0B1D0F4A2A11","text":"スーパー","category":"MKPOICategoryFoodMarket",
              "color":"orange","isVisible":true},
             {"id":"0C6E5B43-5C55-4B8B-8F0E-3A0E3B0D9C22","text":"ラーメン","color":"skyBlue","isVisible":false}]
            """
        defaults.set(Data(layerVersion.utf8), forKey: "savedTabs.v1")

        let store = BrowserStore(searcher: searcher, storage: UserDefaultsTabStorage(defaults: defaults))

        #expect(store.browser.tabs.map(\.query) == [supermarket, SearchQuery(text: "ラーメン", category: nil)])
        #expect(store.browser.tabs.map(\.color) == [.orange, .skyBlue])
        #expect(store.browser.tabs.first?.id.rawValue.uuidString == "6F1B7C0E-6C0B-4F0A-9E57-0B1D0F4A2A11")
    }
}
