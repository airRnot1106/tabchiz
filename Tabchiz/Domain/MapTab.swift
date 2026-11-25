import Foundation

nonisolated struct TabID: Hashable, Sendable, Codable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// One independent map: its own search, camera, viewed place, back history and pins.
nonisolated struct MapTab: Hashable, Sendable, Identifiable {
    let id: TabID
    let color: TabColor
    private(set) var current: Entry
    private(set) var backStack: [Entry] = []
    /// In the order they were added. Searching, opening a page and going back never change them.
    private(set) var pins: [Pin]

    /// A tab that shows the results of `query`, not searched yet, or a blank tab when `query` is nil.
    init(id: TabID = TabID(), color: TabColor, query: SearchQuery?, camera: CameraRegion, pins: [Pin] = []) {
        self.id = id
        self.color = color
        self.pins = pins
        let page: Page = query.map { .results(Search(query: $0, region: camera), .idle) } ?? .blank
        current = Entry(page: page, camera: camera)
    }

    var query: SearchQuery? { current.page.search?.query }
    var places: [Place] { current.page.places }
    var canGoBack: Bool { !backStack.isEmpty }

    var viewedPlace: Place? {
        if case .place(let shown) = current.page { shown.place } else { nil }
    }

    var viewedPin: Pin? {
        guard let pinID = current.page.pinID else { return nil }
        return pins.first { $0.id == pinID }
    }

    /// The place or the pin the tab's page is about.
    var viewedSpot: Spot? {
        viewedPlace.map(Spot.place) ?? viewedPin.map(Spot.pin)
    }

    /// Everything the tab puts on its map: its pins, then its places. A pinned place counts as the pin only.
    var spots: [Spot] {
        pins.map(Spot.pin) + places.filter { pin(for: $0.id) == nil }.map(Spot.place)
    }

    /// The pin made from that search result, if the tab has one.
    func pin(for placeID: PlaceID) -> Pin? {
        pins.first { $0.origin == .place(placeID) }
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
        case .results, .place, .pin:
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

    /// Shows the place page of one of the places on the map. From a results page or a pin page that page goes to
    /// the history. From a place page the sibling replaces the viewed place, so back still returns to the results.
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
        case .pin(let viewed):
            guard let search = viewed.search, let shown = PlacePage(placeID, among: viewed.state.places, of: search)
            else { return false }
            backStack.append(current)
            current.page = .place(shown)
            return true
        case .blank, .results:
            return false
        }
    }

    /// Leaves a place page or a pin page for the results it was opened over. The page it leaves goes to the
    /// history.
    mutating func showResults() {
        let results: Page
        switch current.page {
        case .place(let viewed):
            results = .results(viewed.search, .loaded(viewed.places))
        case .pin(let viewed):
            guard let search = viewed.search else { return }
            results = .results(search, viewed.state)
        case .blank, .results:
            return
        }
        backStack.append(current)
        current.page = results
    }

    /// Returns to the previous page and its camera.
    mutating func back() {
        guard let previous = backStack.popLast() else { return }
        current = previous
    }

    // MARK: Pins

    /// Adds a pin where the map was pressed. It is named "ピン N" with the lowest N no pin of the tab is named by.
    @discardableResult
    mutating func dropPin(at coordinate: Coordinate, id: PinID = PinID()) -> Pin {
        let names = Set(pins.map(\.name))
        var number = 1
        while names.contains(Pin.defaultName(number)) {
            number += 1
        }
        let pin = Pin(id: id, name: Pin.defaultName(number), coordinate: coordinate, origin: .dropped)
        pins.append(pin)
        return pin
    }

    /// Pins one of the places on the map under the place's name. Returns nil and changes nothing when the place
    /// is not on the map or the tab already has a pin for it.
    @discardableResult
    mutating func pinPlace(_ placeID: PlaceID, id: PinID = PinID()) -> Pin? {
        guard pin(for: placeID) == nil, let place = places.first(where: { $0.id == placeID }) else { return nil }
        let pin = Pin(id: id, name: place.name, coordinate: place.coordinate, origin: .place(placeID))
        pins.append(pin)
        return pin
    }

    /// Renames a pin. A blank name is ignored. With `expected`, the pin is renamed only while it still has that
    /// name, so an address that arrives late does not replace a name the user typed.
    mutating func renamePin(_ id: PinID, to name: String, ifStillNamed expected: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = pins.firstIndex(where: { $0.id == id }) else { return }
        if let expected, pins[index].name != expected { return }
        pins[index].name = trimmed
    }

    /// Removes a pin and its pages from the history. A tab that shows the pin's page goes back.
    /// Returns false when the tab has no such pin.
    @discardableResult
    mutating func removePin(_ id: PinID) -> Bool {
        guard let index = pins.firstIndex(where: { $0.id == id }) else { return false }
        pins.remove(at: index)
        backStack.removeAll { $0.page.pinID == id }
        if current.page.pinID == id {
            // A pin page is always opened over another page, so there is one to return to.
            current = backStack.popLast() ?? Entry(page: .blank, camera: current.camera)
        }
        return true
    }

    /// Shows the page of one of the tab's pins. The page it replaces goes to the history, except another pin's
    /// page, so back returns to what the tab showed before any pin. Returns false when the tab has no such pin.
    @discardableResult
    mutating func openPin(_ id: PinID) -> Bool {
        guard pins.contains(where: { $0.id == id }) else { return false }
        if current.page.pinID == id { return true }
        if current.page.pinID == nil {
            backStack.append(current)
        }
        current.page = .pin(PinPage(id, over: current.page))
        return true
    }
}
