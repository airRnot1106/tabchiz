/// What a search asks for: a query inside a region. Results belong to exactly one search.
nonisolated struct Search: Hashable, Sendable {
    let query: SearchQuery
    let region: CameraRegion
}

/// A place together with the loaded results it was opened from. The place is always one of those results, so the
/// map can keep showing its siblings.
nonisolated struct PlacePage: Hashable, Sendable {
    let search: Search
    let places: [Place]
    private let index: Int

    var place: Place { places[index] }

    /// Nil when `placeID` is not among `places`.
    init?(_ placeID: PlaceID, among places: [Place], of search: Search) {
        guard let index = places.firstIndex(where: { $0.id == placeID }) else { return nil }
        self.search = search
        self.places = places
        self.index = index
    }
}

/// A pin together with the search the tab showed when the pin was opened, so the map keeps showing those results.
/// The page holds only the pin's ID. `MapTab` drops every pin page of a pin it removes, so the ID always names one
/// of the tab's pins.
nonisolated struct PinPage: Hashable, Sendable {
    let pinID: PinID
    /// Nil when the pin was opened from a blank page.
    let search: Search?
    let state: SearchState

    /// The page of `pinID` over what `page` shows.
    init(_ pinID: PinID, over page: Page) {
        self.pinID = pinID
        switch page {
        case .blank:
            search = nil
            state = .idle
        case .results(let search, let state):
            self.search = search
            self.state = state
        case .place(let shown):
            search = shown.search
            state = .loaded(shown.places)
        case .pin(let shown):
            search = shown.search
            state = shown.state
        }
    }
}

/// What a tab shows.
nonisolated enum Page: Hashable, Sendable {
    /// A new tab that has not searched yet.
    case blank
    case results(Search, SearchState)
    case place(PlacePage)
    case pin(PinPage)

    var search: Search? {
        switch self {
        case .blank: nil
        case .results(let search, _): search
        case .place(let shown): shown.search
        case .pin(let shown): shown.search
        }
    }

    /// The places the tab's map draws.
    var places: [Place] {
        switch self {
        case .blank: []
        case .results(_, let state): state.places
        case .place(let shown): shown.places
        case .pin(let shown): shown.state.places
        }
    }

    var pinID: PinID? {
        if case .pin(let shown) = self { shown.pinID } else { nil }
    }
}

/// One step of a tab's history. The camera is kept with the page, so going back restores the map as well.
nonisolated struct Entry: Hashable, Sendable {
    var page: Page
    var camera: CameraRegion
}
