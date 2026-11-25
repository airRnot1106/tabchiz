import Foundation
import Testing

@testable import Tabchiz

@MainActor
struct BrowserStorePinsTests {
    typealias Samples = SamplePlaces

    let west = Coordinate(latitude: 35.6749, longitude: 139.7164)
    let east = Coordinate(latitude: 35.6764, longitude: 139.7274)
    let searcher = StubSearcher(results: [
        "スーパー": [Samples.market], "ジム": Samples.gyms,
    ])

    private func store(namer: StubNamer = StubNamer(), storage: any TabStorage = MemoryStorage()) -> BrowserStore {
        BrowserStore(searcher: searcher, namer: namer, storage: storage)
    }

    /// A store with a blank tab that holds a pin on the sample supermarket, a loaded スーパー tab and a loaded ジム tab, showing
    /// the blank tab.
    private func storeWithAPinAndTwoSearches() async throws -> (store: BrowserStore, pin: PinRef) {
        let store = store()
        let apartments = store.browser.activeTab.id
        let dropped = store.dropPin(at: Samples.market.coordinate, in: apartments)
        let pin = try #require(dropped)
        store.submit(LoadedBrowser.supermarket, in: try #require(store.addTab()))
        store.submit(LoadedBrowser.gym, in: try #require(store.addTab()))
        await store.waitForSearches()
        store.showTab(apartments)
        return (store, PinRef(tabID: apartments, pinID: pin.id))
    }

    // MARK: Naming

    @Test func aDroppedPinShowsAtOnceAndTakesTheNameOfItsSpotWhenItArrives() async {
        let namer = StubNamer("テスト町1丁目1-3", delay: .milliseconds(50))
        let store = store(namer: namer)
        let id = store.browser.activeTab.id

        store.dropPin(at: west, in: id)

        #expect(store.browser.activeTab.pins.map(\.name) == ["ピン 1"])
        #expect(store.browser.activeTab.pins.map(\.coordinate) == [west])

        await store.waitForPinNames()

        #expect(store.browser.activeTab.pins.map(\.name) == ["テスト町1丁目1-3"])
        #expect(namer.coordinates == [west])
    }

    @Test func aPinWhoseSpotHasNoNameKeepsItsNumber() async {
        let store = store(namer: StubNamer(nil))
        let id = store.browser.activeTab.id

        store.dropPin(at: west, in: id)
        store.dropPin(at: east, in: id)
        await store.waitForPinNames()

        #expect(store.browser.activeTab.pins.map(\.name) == ["ピン 1", "ピン 2"])
    }

    @Test func aNameTheUserTypedIsKeptWhenTheSpotsNameArrives() async throws {
        let store = store(namer: StubNamer("テスト町1丁目1-3", delay: .milliseconds(50)))
        let id = store.browser.activeTab.id
        let dropped = store.dropPin(at: west, in: id)
        let pin = try #require(dropped)

        store.renamePin(PinRef(tabID: id, pinID: pin.id), to: "テスト住まい西")
        await store.waitForPinNames()

        #expect(store.browser.activeTab.pins.map(\.name) == ["テスト住まい西"])
    }

    @Test func aPinRemovedBeforeItsNameArrivesStaysRemoved() async throws {
        let store = store(namer: StubNamer("テスト町1丁目1-3", delay: .milliseconds(50)))
        let id = store.browser.activeTab.id
        let dropped = store.dropPin(at: west, in: id)
        let pin = try #require(dropped)

        store.removePin(PinRef(tabID: id, pinID: pin.id))
        await store.waitForPinNames()

        #expect(store.browser.activeTab.pins.isEmpty)
    }

    // MARK: Saved pins

    @Test func pinsAreSavedWithTheirTabEvenWhenTheTabIsBlank() async throws {
        let storage = MemoryStorage()
        let store = store(namer: StubNamer("テスト町1丁目1-3"), storage: storage)
        let blank = store.browser.activeTab.id
        store.dropPin(at: west, in: blank)
        await store.waitForPinNames()
        let gyms = try #require(store.addTab())
        store.submit(LoadedBrowser.gym, in: gyms)
        await store.waitForSearches()
        store.pinPlace(Samples.southGym.id, in: gyms)

        #expect(storage.saved.map(\.text) == [nil, "ジム"])
        #expect(storage.saved.map { $0.pins.map(\.name) } == [["テスト町1丁目1-3"], [Samples.southGym.name]])
        #expect(storage.saved.map { $0.pins.map(\.pin) } == store.browser.tabs.map(\.pins))

        store.removePin(PinRef(tabID: blank, pinID: store.browser.tabs[0].pins[0].id))

        #expect(storage.saved.map(\.pins.count) == [0, 1])
    }

    @Test func aRelaunchRestoresThePinsOfEveryTab() async throws {
        let defaults = try #require(UserDefaults(suiteName: "BrowserStorePinsTests.\(UUID().uuidString)"))
        let storage = UserDefaultsTabStorage(defaults: defaults)
        let first = store(namer: StubNamer("テスト町1丁目1-3"), storage: storage)
        let blank = first.browser.activeTab.id
        first.dropPin(at: west, in: blank)
        first.dropPin(at: east, in: blank)
        await first.waitForPinNames()
        first.renamePin(PinRef(tabID: blank, pinID: first.browser.tabs[0].pins[1].id), to: "テスト住まい東")
        let gyms = try #require(first.addTab())
        first.submit(LoadedBrowser.gym, in: gyms)
        await first.waitForSearches()
        first.pinPlace(Samples.southGym.id, in: gyms)

        let second = store(storage: storage)
        await second.launch()

        #expect(second.browser.tabs.map(\.pins) == first.browser.tabs.map(\.pins))
        #expect(second.browser.tabs[0].pins.map(\.name) == ["テスト町1丁目1-3", "テスト住まい東"])
        #expect(second.browser.tabs[0].pins.map(\.origin) == [.dropped, .dropped])
        #expect(second.browser.tabs[0].query == nil)
        #expect(second.browser.tabs[1].pins.map(\.origin) == [.place(Samples.southGym.id)])
        #expect(second.browser.tabs[1].places == Samples.gyms)
        #expect(second.browser.tabs[1].pin(for: Samples.southGym.id) != nil)
    }

    @Test func tabsSavedBeforePinsExistedLoadWithoutPins() throws {
        let suite = "BrowserStorePinsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let withoutPins = """
            [{"id":"6F1B7C0E-6C0B-4F0A-9E57-0B1D0F4A2A11","text":"スーパー","category":"MKPOICategoryFoodMarket",
              "color":"orange"},
             {"id":"0C6E5B43-5C55-4B8B-8F0E-3A0E3B0D9C22","color":"skyBlue"}]
            """
        defaults.set(Data(withoutPins.utf8), forKey: "savedTabs.v1")

        let store = store(storage: UserDefaultsTabStorage(defaults: defaults))

        #expect(store.browser.tabs.map(\.query) == [LoadedBrowser.supermarket, nil])
        #expect(store.browser.tabs.map(\.color) == [.orange, .skyBlue])
        #expect(store.browser.tabs.map(\.pins) == [[], []])
    }

    @Test func savedPinsLoadFromTheirSavedForm() throws {
        let suite = "BrowserStorePinsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let withPins = """
            [{"id":"6F1B7C0E-6C0B-4F0A-9E57-0B1D0F4A2A11","color":"orange","pins":[
              {"id":"11111111-1111-4111-8111-111111111111","name":"テスト住まい西","latitude":35.6749,"longitude":139.7164},
              {"id":"22222222-2222-4222-8222-222222222222","name":"テストジムC","latitude":35.681,
               "longitude":139.725,"placeID":"sample-gym-c"}]}]
            """
        defaults.set(Data(withPins.utf8), forKey: "savedTabs.v1")

        let store = store(storage: UserDefaultsTabStorage(defaults: defaults))

        let pins = store.browser.activeTab.pins
        #expect(pins.map(\.name) == ["テスト住まい西", "テストジムC"])
        #expect(pins.map(\.coordinate) == [west, Samples.farGym.coordinate])
        #expect(pins.map(\.origin) == [.dropped, .place(Samples.farGym.id)])
        #expect(pins.map(\.id.rawValue.uuidString).first == "11111111-1111-4111-8111-111111111111")
        #expect(store.browser.activeTab.current.page == .blank)
    }

    // MARK: Cameras

    @Test func goingBackToAPinPageOverASearchThatNeverLoadedSearchesItAgain() async throws {
        let slow = StubSearcher(
            results: ["スーパー": [Samples.market], "ジム": Samples.gyms],
            delays: ["スーパー": .milliseconds(100)]
        )
        let store = BrowserStore(searcher: slow, namer: StubNamer(), storage: MemoryStorage())
        let id = store.browser.activeTab.id
        let dropped = store.dropPin(at: west, in: id)
        let pin = try #require(dropped)
        store.submit(LoadedBrowser.supermarket, in: id)
        store.openPin(PinRef(tabID: id, pinID: pin.id))
        store.submit(LoadedBrowser.gym, in: id)
        await store.waitForSearches()

        store.back(in: id)
        await store.waitForSearches()

        #expect(store.browser.activeTab.viewedPin?.id == pin.id)
        #expect(store.browser.activeTab.places == [Samples.market])
    }

    @Test func openingAPinFramesItWithTheNearestSpotOfEachOtherTab() async throws {
        let (store, pin) = try await storeWithAPinAndTwoSearches()

        store.openPin(pin)

        #expect(store.browser.activeTab.viewedPin?.id == pin.pinID)
        #expect(
            store.cameraCommand?.target
                == .fit([
                    Samples.market.coordinate, Samples.market.coordinate,
                    Samples.nearGym.coordinate,
                ])
        )
    }

    @Test func pickingAPinAsTheNearestSpotOfAPlaceOpensThePinInItsTab() async throws {
        let (store, pin) = try await storeWithAPinAndTwoSearches()
        let gyms = store.browser.tabs[2].id
        store.showTab(gyms)
        store.openPlace(Samples.nearGym.id, in: gyms)
        let nearest = try #require(store.browser.nearestToViewedSpot(in: gyms).first)
        #expect(nearest.tabID == pin.tabID)
        #expect(abs(nearest.distance - 133.43) < 1)

        store.jump(to: nearest.spot, in: nearest.tabID)

        #expect(store.browser.mode == .tab(pin.tabID))
        #expect(store.browser.activeTab.viewedPin?.id == pin.pinID)
    }

    @Test func theOverviewFramesEveryPinAndEveryPlace() async throws {
        let (store, _) = try await storeWithAPinAndTwoSearches()

        store.toggleOverview()

        let everySpot = ([Samples.market, Samples.market] + Samples.gyms).map(\.coordinate)
        #expect(store.cameraCommand?.target == .fit(everySpot))
    }

    @Test func selectingAPinInTheOverviewFramesItWithItsNearestSpotsAndClearingLeavesTheMapAlone() async throws {
        let (store, pin) = try await storeWithAPinAndTwoSearches()
        store.toggleOverview()
        store.cameraDidChange(LoadedBrowser.southArea, in: .overview)

        store.selectPinInOverview(pin)

        #expect(store.browser.mode == .overview(returnTo: pin.tabID, selected: pin))
        let framed = store.cameraCommand
        #expect(
            framed?.target
                == .fit([
                    Samples.market.coordinate, Samples.market.coordinate,
                    Samples.nearGym.coordinate,
                ])
        )

        store.selectPinInOverview(nil)

        #expect(store.browser.mode == .overview(returnTo: pin.tabID))
        #expect(store.cameraCommand == framed)
    }
}
