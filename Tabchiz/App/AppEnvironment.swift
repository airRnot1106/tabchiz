import Foundation

/// How the app is wired for this launch. UI tests pass `-UITestFixture` to search the bundled snapshot with
/// empty saved tabs, and `-SeedTabs スーパー,ジム` to start with those tabs instead of the saved ones.
struct AppEnvironment {
    let usesFixture: Bool
    let seedQueries: [String]?

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        usesFixture = arguments.contains("-UITestFixture")
        if let index = arguments.firstIndex(of: "-SeedTabs"), arguments.indices.contains(index + 1) {
            seedQueries = arguments[index + 1].split(separator: ",").map(String.init)
        } else {
            seedQueries = nil
        }
    }

    func makeStore() -> BrowserStore {
        let storage: UserDefaultsTabStorage
        if usesFixture {
            let suite = "dev.airrnot.tabchiz.uitest"
            UserDefaults().removePersistentDomain(forName: suite)
            storage = UserDefaultsTabStorage(defaults: UserDefaults(suiteName: suite) ?? .standard)
        } else {
            storage = UserDefaultsTabStorage(defaults: .standard)
        }
        if let seedQueries {
            storage.save(
                zip(seedQueries, TabColor.allCases).map { text, color in
                    SavedTab(query: SearchQuery(text: text), color: color)
                }
            )
        }
        if usesFixture {
            return BrowserStore(searcher: FixturePlaceSearcher(), storage: storage)
        }
        return BrowserStore(
            searcher: MapKitPlaceSearcher(),
            storage: storage,
            locate: { await CurrentLocation.fetch() }
        )
    }
}
