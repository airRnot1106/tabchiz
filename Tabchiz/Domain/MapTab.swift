import Foundation

nonisolated struct TabID: Hashable, Sendable, Codable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// One independent map: its own search, camera, viewed place and back history.
nonisolated struct MapTab: Hashable, Sendable, Identifiable {
    let id: TabID
    let color: TabColor
    private(set) var current: Entry
    private(set) var backStack: [Entry] = []

    /// A tab that shows the results of `query`, not searched yet, or a blank tab when `query` is nil.
    init(id: TabID = TabID(), color: TabColor, query: SearchQuery?, camera: CameraRegion) {
        self.id = id
        self.color = color
        let page: Page = query.map { .results(Search(query: $0, region: camera), .idle) } ?? .blank
        current = Entry(page: page, camera: camera)
    }

    var query: SearchQuery? { current.page.search?.query }
    var places: [Place] { current.page.places }
    var canGoBack: Bool { !backStack.isEmpty }

    var viewedPlace: Place? {
        if case .place(let shown) = current.page { shown.place } else { nil }
    }

    mutating func setCamera(_ camera: CameraRegion) {
        current.camera = camera
    }

    /// Shows the results page of `query` for the area the map shows. The page it replaces goes to the history,
    /// except a blank page and a results page of the same query, which have nothing to come back to.
    mutating func submit(_ query: SearchQuery) {
        switch current.page {
        case .blank:
            break
        case .results(let search, _) where search.query == query:
            break
        case .results, .place:
            backStack.append(current)
        }
        current.page = .results(Search(query: query, region: current.camera), .idle)
    }

    /// Asks the results page for the area the map shows now. The old results belong to the old area and are dropped.
    mutating func searchHere() {
        guard case .results(let search, _) = current.page else { return }
        current.page = .results(Search(query: search.query, region: current.camera), .idle)
    }

    /// Applies a search state only while the tab still shows the results page of that search. A late result for a
    /// search the tab has since left is ignored.
    mutating func apply(_ state: SearchState, for search: Search) {
        guard case .results(search, _) = current.page else { return }
        current.page = .results(search, state)
    }

    /// Shows the place page of one of the places on the map. From a results page the results go to the history.
    /// From a place page the sibling replaces the viewed place, so back still returns to the results.
    /// Returns false and changes nothing when the place is not on the map.
    @discardableResult
    mutating func open(_ placeID: PlaceID) -> Bool {
        switch current.page {
        case .results(let search, .loaded(let places)):
            guard let shown = PlacePage(placeID, among: places, of: search) else { return false }
            backStack.append(current)
            current.page = .place(shown)
            return true
        case .place(let viewed):
            guard let shown = PlacePage(placeID, among: viewed.places, of: viewed.search) else { return false }
            current.page = .place(shown)
            return true
        case .blank, .results:
            return false
        }
    }

    /// Leaves a place page for the results it was opened from. The place page goes to the history.
    mutating func showResults() {
        guard case .place(let viewed) = current.page else { return }
        backStack.append(current)
        current.page = .results(viewed.search, .loaded(viewed.places))
    }

    /// Returns to the previous page and its camera.
    mutating func back() {
        guard let previous = backStack.popLast() else { return }
        current = previous
    }
}
