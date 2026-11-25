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

/// What a tab shows.
nonisolated enum Page: Hashable, Sendable {
    /// A new tab that has not searched yet.
    case blank
    case results(Search, SearchState)
    case place(PlacePage)

    var search: Search? {
        switch self {
        case .blank: nil
        case .results(let search, _): search
        case .place(let shown): shown.search
        }
    }

    /// The places the tab's map draws.
    var places: [Place] {
        switch self {
        case .blank: []
        case .results(_, let state): state.places
        case .place(let shown): shown.places
        }
    }
}

/// One step of a tab's history. The camera is kept with the page, so going back restores the map as well.
nonisolated struct Entry: Hashable, Sendable {
    var page: Page
    var camera: CameraRegion
}
