/// Which map is on screen.
nonisolated enum MapScene: Hashable, Sendable {
    case tab(TabID)
    case overview
}

nonisolated enum Mode: Hashable, Sendable {
    case tab(TabID)
    /// Every tab's results on one map. `returnTo` is the tab the overview was entered from.
    case overview(returnTo: TabID)

    var scene: MapScene {
        switch self {
        case .tab(let id): .tab(id)
        case .overview: .overview
        }
    }

    /// The tab on screen, or the tab the overview returns to.
    var tabID: TabID {
        switch self {
        case .tab(let id), .overview(let id): id
        }
    }
}

/// One to five independent map tabs and the overview derived from them. Every rule about which combinations are
/// allowed lives here and in `MapTab`, so the store only forwards user actions and search results.
nonisolated struct Browser: Hashable, Sendable {
    static let maxTabs = 5

    private(set) var tabs: [MapTab]
    private(set) var mode: Mode
    /// Where the overview map was left. Nil until the overview has been shown, and again after results change,
    /// so the overview then frames every place.
    private(set) var overviewCamera: CameraRegion?

    /// Starts on the first tab. Without tabs it starts with one blank tab, because a browser always has a tab.
    init(tabs: [MapTab] = [], camera: CameraRegion = .defaultArea) {
        let kept = Array(tabs.prefix(Self.maxTabs))
        self.tabs = kept.isEmpty ? [MapTab(color: .orange, query: nil, camera: camera)] : kept
        mode = .tab(self.tabs[0].id)
    }

    var canAddTab: Bool { tabs.count < Self.maxTabs }

    /// The tab on screen, or the tab the overview returns to.
    var activeTab: MapTab { tab(mode.tabID) ?? tabs[0] }

    func tab(_ id: TabID) -> MapTab? {
        tabs.first { $0.id == id }
    }

    // MARK: Tabs

    /// Opens a blank tab with the first free color on the area the active tab shows, and switches to it.
    /// Returns nil and changes nothing when five tabs exist.
    @discardableResult
    mutating func addTab(id: TabID = TabID()) -> TabID? {
        guard canAddTab, let color = TabColor.firstFree(excluding: tabs.map(\.color)) else { return nil }
        tabs.append(MapTab(id: id, color: color, query: nil, camera: activeTab.current.camera))
        mode = .tab(id)
        return id
    }

    /// Closes a tab. Closing the tab on screen shows its right neighbor, or its left neighbor when it was the last
    /// one. Closing the only tab leaves a blank tab on the same area.
    mutating func removeTab(_ id: TabID) {
        guard let index = index(of: id) else { return }
        let removed = tabs.remove(at: index)
        if tabs.isEmpty {
            tabs = [MapTab(color: removed.color, query: nil, camera: removed.current.camera)]
        }
        let neighbor = tabs[min(index, tabs.count - 1)].id
        switch mode {
        case .tab(id): mode = .tab(neighbor)
        case .overview(returnTo: id): mode = .overview(returnTo: neighbor)
        case .tab, .overview: break
        }
    }

    mutating func showTab(_ id: TabID) {
        guard index(of: id) != nil else { return }
        mode = .tab(id)
    }

    mutating func showOverview() {
        mode = .overview(returnTo: mode.tabID)
    }

    /// Leaves the overview for the tab it was entered from.
    mutating func leaveOverview() {
        mode = .tab(mode.tabID)
    }

    // MARK: Pages

    mutating func submit(_ query: SearchQuery, in id: TabID) {
        update(id) { $0.submit(query) }
    }

    mutating func searchHere(in id: TabID) {
        update(id) { $0.searchHere() }
    }

    mutating func applySearch(_ state: SearchState, for search: Search, in id: TabID) {
        guard let index = index(of: id) else { return }
        let before = tabs[index].places
        tabs[index].apply(state, for: search)
        if tabs[index].places != before {
            overviewCamera = nil
        }
    }

    mutating func openPlace(_ placeID: PlaceID, in id: TabID) {
        update(id) { $0.open(placeID) }
    }

    mutating func back(in id: TabID) {
        update(id) { $0.back() }
    }

    /// Switches to the tab and shows the place there. Used from the overview and from another tab's place page.
    /// Changes nothing when the tab does not show that place on its map.
    mutating func jump(to placeID: PlaceID, in id: TabID) {
        guard let index = index(of: id), tabs[index].open(placeID) else { return }
        mode = .tab(id)
    }

    /// Switches to the tab and shows its results page, for a cluster picked in the overview.
    mutating func jumpToResults(in id: TabID) {
        guard let index = index(of: id) else { return }
        tabs[index].showResults()
        mode = .tab(id)
    }

    // MARK: Cameras

    mutating func setCamera(_ camera: CameraRegion, for scene: MapScene) {
        switch scene {
        case .tab(let id): update(id) { $0.setCamera(camera) }
        case .overview: overviewCamera = camera
        }
    }

    /// Moves every tab's map to `center`, keeping its zoom.
    mutating func recenter(on center: Coordinate) {
        for index in tabs.indices {
            var camera = tabs[index].current.camera
            camera.center = center
            tabs[index].setCamera(camera)
        }
    }

    // MARK: Nearest

    /// For the place the tab shows, the nearest place of every other tab that has results.
    func nearestToViewedPlace(in id: TabID) -> [NearestMatch] {
        guard let place = tab(id)?.viewedPlace else { return [] }
        return nearestMatches(from: place, excluding: id, in: tabs)
    }

    private func index(of id: TabID) -> Int? {
        tabs.firstIndex { $0.id == id }
    }

    private mutating func update(_ id: TabID, _ change: (inout MapTab) -> Void) {
        guard let index = index(of: id) else { return }
        change(&tabs[index])
    }
}
