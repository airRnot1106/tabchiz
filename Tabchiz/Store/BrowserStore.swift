import Foundation
import MapKit
import Observation

/// Where the map on screen should go next. The ID changes on every command, so asking for the same target twice
/// moves the camera twice.
struct CameraCommand: Equatable {
    enum Target: Equatable {
        /// Show exactly this region.
        case region(CameraRegion)
        /// Frame these coordinates in the part of the map that no control covers.
        case fit([Coordinate])
    }

    let id: Int
    let target: Target
}

@MainActor
@Observable
final class BrowserStore {
    /// Wait after MapKit itself reports throttling. Requests succeeded again about 10 s after a throttled burst.
    static let mapKitThrottleBackoff: TimeInterval = 10

    private struct RunningSearch {
        let token: Int
        let search: Search
        let task: Task<Void, Never>
    }

    private(set) var browser: Browser
    private(set) var cameraCommand: CameraCommand?

    @ObservationIgnored private let searcher: any PlaceSearcher
    @ObservationIgnored private let storage: any TabStorage
    @ObservationIgnored private let budget: RequestBudget
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let locate: () async -> Coordinate?
    @ObservationIgnored private var searches: [TabID: RunningSearch] = [:]
    @ObservationIgnored private var nextSearchToken = 0
    @ObservationIgnored private var nextCameraCommandID = 0
    @ObservationIgnored private var saved: [SavedTab]

    init(
        searcher: any PlaceSearcher,
        storage: any TabStorage,
        budget: RequestBudget = RequestBudget(),
        now: @escaping () -> Date = { Date() },
        locate: @escaping () async -> Coordinate? = { nil }
    ) {
        self.searcher = searcher
        self.storage = storage
        self.budget = budget
        self.now = now
        self.locate = locate
        saved = storage.load()
        browser = Browser(tabs: saved.map { $0.tab(camera: .defaultArea) })
    }

    /// True when the tab on screen shows results for an area the map has since left.
    var showsResearchButton: Bool {
        guard case .tab(let id) = browser.mode, let tab = browser.tab(id),
            case .results(let search, let state) = tab.current.page
        else { return false }
        switch state {
        case .loaded, .failed: return search.region.needsResearch(for: tab.current.camera)
        case .idle, .searching, .throttled: return false
        }
    }

    // MARK: Actions

    /// Centers every tab on the user when the location is known, then searches every restored tab there.
    func launch() async {
        let center = await locate()
        perform { browser in
            if let center {
                browser.recenter(on: center)
            }
            for tab in browser.tabs {
                browser.searchHere(in: tab.id)
            }
        }
        await waitForSearches()
    }

    @discardableResult
    func addTab() -> TabID? {
        var added: TabID?
        perform { added = $0.addTab() }
        return added
    }

    func removeTab(_ id: TabID) {
        perform { $0.removeTab(id) }
    }

    func showTab(_ id: TabID) {
        perform { $0.showTab(id) }
    }

    /// Enters the overview, or leaves it for the tab it was entered from.
    func toggleOverview() {
        perform { browser in
            if case .overview = browser.mode {
                browser.leaveOverview()
            } else {
                browser.showOverview()
            }
        }
    }

    func submit(_ query: SearchQuery, in id: TabID) {
        perform { $0.submit(query, in: id) }
    }

    /// Searches the tab's query again in the area its map shows now.
    func searchHere(in id: TabID) {
        perform { $0.searchHere(in: id) }
    }

    func back(in id: TabID) {
        perform { $0.back(in: id) }
    }

    /// Shows the place page in the tab that is on screen.
    func openPlace(_ placeID: PlaceID, in id: TabID) {
        perform { $0.openPlace(placeID, in: id) }
        frameViewedPlace(placeID, in: id)
    }

    /// Switches to the tab and shows the place page there.
    func jump(to placeID: PlaceID, in id: TabID) {
        perform { $0.jump(to: placeID, in: id) }
        frameViewedPlace(placeID, in: id)
    }

    /// Switches to the tab's results with its map on the places of a cluster picked in the overview.
    func jumpToResults(framing coordinates: [Coordinate], in id: TabID) {
        perform { $0.jumpToResults(in: id) }
        if browser.mode == .tab(id) {
            moveCamera(to: .fit(coordinates))
        }
    }

    /// The map reports where its camera is after every move.
    func cameraDidChange(_ camera: CameraRegion, in scene: MapScene) {
        browser.setCamera(camera, for: scene)
    }

    /// Waits until no search is running. A search that waits for the request budget counts as running.
    func waitForSearches() async {
        while let running = searches.values.first {
            await running.task.value
        }
    }

    // MARK: Consequences of a change

    /// Applies a user action and everything that follows from the new state: the camera of the map on screen,
    /// searches to start or cancel, and the saved tabs.
    private func perform(_ change: (inout Browser) -> Void) {
        let sceneBefore = browser.mode.scene
        let cameraBefore = cameraOnScreen
        change(&browser)
        // A scene change needs no command: the map shows the new scene's camera by itself.
        if browser.mode.scene == sceneBefore, let camera = cameraOnScreen, camera != cameraBefore {
            moveCamera(to: .region(camera))
        }
        syncSearches()
        frameOverviewIfUnset()
        persist()
    }

    private var cameraOnScreen: CameraRegion? {
        switch browser.mode {
        case .tab: browser.activeTab.current.camera
        case .overview: browser.overviewCamera
        }
    }

    private func frameViewedPlace(_ placeID: PlaceID, in id: TabID) {
        guard browser.mode == .tab(id), let place = browser.tab(id)?.viewedPlace, place.id == placeID else { return }
        moveCamera(to: .fit([place.coordinate] + browser.nearestToViewedPlace(in: id).map(\.place.coordinate)))
    }

    private func frameOverviewIfUnset() {
        guard case .overview = browser.mode, browser.overviewCamera == nil else { return }
        let coordinates = browser.tabs.flatMap(\.places).map(\.coordinate)
        guard !coordinates.isEmpty else { return }
        moveCamera(to: .fit(coordinates))
    }

    private func moveCamera(to target: CameraCommand.Target) {
        nextCameraCommandID += 1
        cameraCommand = CameraCommand(id: nextCameraCommandID, target: target)
    }

    private func persist() {
        let current = browser.tabs.map(SavedTab.init)
        guard current != saved else { return }
        saved = current
        storage.save(current)
    }

    // MARK: Searching

    /// Cancels the search of every tab that no longer shows its results page, and starts one for every results
    /// page that still waits for results. Each tab keeps its own task.
    private func syncSearches() {
        for (id, running) in searches where browser.tab(id)?.current.page.search != running.search {
            running.task.cancel()
            searches[id] = nil
        }
        for tab in browser.tabs where searches[tab.id] == nil {
            guard case .results(let search, let state) = tab.current.page else { continue }
            switch state {
            case .idle, .searching, .throttled:
                let id = tab.id
                nextSearchToken += 1
                let token = nextSearchToken
                browser.applySearch(.searching, for: search, in: id)
                let task = Task { await self.run(search, for: id, token: token) }
                searches[id] = RunningSearch(token: token, search: search, task: task)
            case .loaded, .failed:
                break
            }
        }
    }

    private func run(_ search: Search, for id: TabID, token: Int) async {
        defer {
            if searches[id]?.token == token {
                searches[id] = nil
            }
        }
        while !Task.isCancelled {
            let retryAt: Date
            switch await budget.reserve() {
            case .denied(let budgetRetryAt):
                retryAt = budgetRetryAt
            case .granted:
                do {
                    let places = try await searcher.search(search.query, region: search.region)
                    guard !Task.isCancelled else { return }
                    apply(.loaded(places.dedupedByID()), for: search, in: id)
                    return
                } catch PlaceSearchError.throttled {
                    retryAt = now().addingTimeInterval(Self.mapKitThrottleBackoff)
                } catch {
                    guard !Task.isCancelled else { return }
                    apply(.failed(message: error.localizedDescription), for: search, in: id)
                    return
                }
            }
            guard !Task.isCancelled else { return }
            apply(.throttled(retryAt: retryAt), for: search, in: id)
            try? await Task.sleep(for: .seconds(max(retryAt.timeIntervalSince(now()), 0)))
            guard !Task.isCancelled else { return }
            apply(.searching, for: search, in: id)
        }
    }

    private func apply(_ state: SearchState, for search: Search, in id: TabID) {
        browser.applySearch(state, for: search, in: id)
        frameOverviewIfUnset()
    }
}
