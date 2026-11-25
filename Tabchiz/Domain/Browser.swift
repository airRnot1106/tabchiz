/// Which map is on screen.
nonisolated enum MapScene: Hashable, Sendable {
    case tab(TabID)
    case overview
}

nonisolated enum Mode: Hashable, Sendable {
    case tab(TabID)
    /// Every tab's results and pins on one map. `returnTo` is the tab the overview was entered from. `selected`
    /// is the pin whose nearest spots the overview shows.
    case overview(returnTo: TabID, selected: PinRef? = nil)

    var scene: MapScene {
        switch self {
        case .tab(let id): .tab(id)
        case .overview: .overview
        }
    }

    /// The tab on screen, or the tab the overview returns to.
    var tabID: TabID {
        switch self {
        case .tab(let id), .overview(let id, _): id
        }
    }
}

/// One to five independent map tabs with their pins, and the overview derived from them. Every rule about which combinations are
/// allowed lives here and in `MapTab`, so the store only forwards user actions and search results.
nonisolated struct Browser: Hashable, Sendable {
    static let maxTabs = 5

    private(set) var tabs: [MapTab] {
        didSet {
            if tabs.flatMap(\.places) != oldValue.flatMap(\.places) {
                overviewCamera = nil
            }
        }
    }
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

    /// Closes a tab and removes its pins. Closing the tab on screen shows its right neighbor, or its left neighbor
    /// when it was the last one. Closing the only tab leaves a blank tab on the same area.
    mutating func removeTab(_ id: TabID) {
        guard let index = index(of: id) else { return }
        let removed = tabs.remove(at: index)
        if tabs.isEmpty {
            tabs = [MapTab(color: removed.color, query: nil, camera: removed.current.camera)]
        }
        let neighbor = tabs[min(index, tabs.count - 1)].id
        switch mode {
        case .tab(id):
            mode = .tab(neighbor)
        case .tab:
            break
        case .overview(let returnTo, let selected):
            mode = .overview(
                returnTo: returnTo == id ? neighbor : returnTo,
                selected: selected?.tabID == id ? nil : selected
            )
        }
        if !removed.pins.isEmpty {
            overviewCamera = nil
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
        update(id) { $0.apply(state, for: search) }
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

    // MARK: Pins

    /// Adds a pin to the tab where its map was pressed. Returns nil when the tab does not exist.
    @discardableResult
    mutating func dropPin(at coordinate: Coordinate, in id: TabID, pinID: PinID = PinID()) -> Pin? {
        guard let index = index(of: id) else { return nil }
        overviewCamera = nil
        return tabs[index].dropPin(at: coordinate, id: pinID)
    }

    /// Pins one of the places the tab shows. Returns nil and changes nothing when the tab does not show the place
    /// or already has a pin for it. Another tab can pin the same place.
    @discardableResult
    mutating func pinPlace(_ placeID: PlaceID, in id: TabID, pinID: PinID = PinID()) -> Pin? {
        guard let index = index(of: id), let pin = tabs[index].pinPlace(placeID, id: pinID) else { return nil }
        overviewCamera = nil
        return pin
    }

    /// Renames a pin. With `expected`, only while the pin still has that name.
    mutating func renamePin(_ ref: PinRef, to name: String, ifStillNamed expected: String? = nil) {
        update(ref.tabID) { $0.renamePin(ref.pinID, to: name, ifStillNamed: expected) }
    }

    /// Removes a pin. A tab that shows the pin's page goes back, and the overview no longer selects the pin.
    mutating func removePin(_ ref: PinRef) {
        guard let index = index(of: ref.tabID), tabs[index].removePin(ref.pinID) else { return }
        overviewCamera = nil
        if case .overview(let returnTo, ref) = mode {
            mode = .overview(returnTo: returnTo)
        }
    }

    /// Switches to the pin's tab and shows the pin's page there. Changes nothing when the pin does not exist.
    mutating func openPin(_ ref: PinRef) {
        guard let index = index(of: ref.tabID), tabs[index].openPin(ref.pinID) else { return }
        mode = .tab(ref.tabID)
    }

    /// In the overview, selects the pin whose nearest spots are shown, or clears the selection with nil. The
    /// overview stays on screen. Changes nothing outside the overview or for a pin that does not exist.
    mutating func selectPinInOverview(_ ref: PinRef?) {
        guard case .overview(let returnTo, _) = mode else { return }
        if let ref, tab(ref.tabID)?.pins.contains(where: { $0.id == ref.pinID }) != true { return }
        mode = .overview(returnTo: returnTo, selected: ref)
    }

    /// The pin the overview has selected, with its tab.
    var selectedPin: (tab: MapTab, pin: Pin)? {
        guard case .overview(_, let selected?) = mode, let tab = tab(selected.tabID),
            let pin = tab.pins.first(where: { $0.id == selected.pinID })
        else { return nil }
        return (tab, pin)
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

    /// For the place or the pin the tab shows, the nearest spot of every other tab that has pins or results.
    func nearestToViewedSpot(in id: TabID) -> [NearestMatch] {
        guard let spot = tab(id)?.viewedSpot else { return [] }
        return nearestMatches(from: spot.coordinate, excluding: id, in: tabs)
    }

    /// For the pin the overview has selected, the nearest spot of every other tab that has pins or results.
    func nearestToSelectedPin() -> [NearestMatch] {
        guard let selected = selectedPin else { return [] }
        return nearestMatches(from: selected.pin.coordinate, excluding: selected.tab.id, in: tabs)
    }

    private func index(of id: TabID) -> Int? {
        tabs.firstIndex { $0.id == id }
    }

    private mutating func update(_ id: TabID, _ change: (inout MapTab) -> Void) {
        guard let index = index(of: id) else { return }
        change(&tabs[index])
    }
}
