import Foundation

/// Everything the map on screen draws, derived from the browser. The map rebuilds its annotations only when this
/// changes.
struct MapContent: Equatable {
    enum Role: Equatable {
        /// A spot of the tab on screen that the tab's page is not about.
        case normal
        /// The spot the tab views, or the pin the overview has selected: enlarged, with its name.
        case selected
        /// The nearest spot of another tab to the selected one, with its straight-line distance.
        case nearest(distance: Double)
        /// Any other place of the tab while a spot is viewed. Pins are never dimmed.
        case dimmed
        /// A spot of any tab in the overview: a place is a dot that clusters only with its own tab, a pin stays
        /// a marker.
        case overview
    }

    struct Marker: Equatable, Identifiable {
        let tabID: TabID
        /// The tab's position in the bar.
        let tabIndex: Int
        let tabName: String
        let symbolName: String
        let color: TabColor
        let spot: Spot
        let role: Role

        var id: String {
            switch spot {
            case .place(let place): "\(tabID.rawValue.uuidString)/place/\(place.id.rawValue)"
            case .pin(let pin): "\(tabID.rawValue.uuidString)/pin/\(pin.id.rawValue.uuidString)"
            }
        }

        var pin: Pin? {
            if case .pin(let pin) = spot { pin } else { nil }
        }
    }

    struct Line: Equatable {
        let origin: Coordinate
        let target: Coordinate
        let color: TabColor
    }

    /// A tab with its position in the bar.
    private struct Layer {
        let index: Int
        let tab: MapTab

        func marker(_ spot: Spot, role: Role) -> Marker {
            Marker(
                tabID: tab.id,
                tabIndex: index,
                tabName: tab.title,
                symbolName: tab.symbolName,
                color: tab.color,
                spot: spot,
                role: role
            )
        }

        /// How the tab draws one of its spots while its page is about `viewed`. A pinned place that is viewed is
        /// drawn as its pin.
        func role(of spot: Spot, viewing viewed: Spot?) -> Role {
            guard let viewed else { return .normal }
            switch spot {
            case .place:
                return spot == viewed ? .selected : .dimmed
            case .pin(let pin):
                if spot == viewed { return .selected }
                if case .place(let place) = viewed, pin.origin == .place(place.id) { return .selected }
                return .normal
            }
        }
    }

    let scene: MapScene
    let markers: [Marker]
    let lines: [Line]

    init(browser: Browser) {
        scene = browser.mode.scene
        let layers = browser.tabs.enumerated().map { Layer(index: $0.offset, tab: $0.element) }
        switch browser.mode {
        case .tab(let id):
            guard let shown = layers.first(where: { $0.tab.id == id }) else {
                markers = []
                lines = []
                return
            }
            let viewed = shown.tab.viewedSpot
            let nearest = browser.nearestToViewedSpot(in: id)
            markers =
                shown.tab.spots.map { shown.marker($0, role: shown.role(of: $0, viewing: viewed)) }
                + nearest.compactMap { match in
                    layers.first { $0.tab.id == match.tabID }?
                        .marker(match.spot, role: .nearest(distance: match.distance))
                }
            lines = Self.lines(from: viewed, to: nearest, in: layers)
        case .overview:
            let selected = browser.selectedPin
            let nearest = browser.nearestToSelectedPin()
            markers = layers.flatMap { layer in
                layer.tab.spots.map { spot in
                    if let selected, layer.tab.id == selected.tab.id, spot == .pin(selected.pin) {
                        return layer.marker(spot, role: .selected)
                    }
                    if let match = nearest.first(where: { $0.tabID == layer.tab.id && $0.spot == spot }) {
                        return layer.marker(spot, role: .nearest(distance: match.distance))
                    }
                    return layer.marker(spot, role: .overview)
                }
            }
            lines = Self.lines(from: selected.map { .pin($0.pin) }, to: nearest, in: layers)
        }
    }

    /// A line from the spot to each of its nearest spots, in the color of the nearest spot's tab.
    private static func lines(from origin: Spot?, to nearest: [NearestMatch], in layers: [Layer]) -> [Line] {
        guard let origin else { return [] }
        return nearest.compactMap { match in
            layers.first { $0.tab.id == match.tabID }.map {
                Line(origin: origin.coordinate, target: match.spot.coordinate, color: $0.tab.color)
            }
        }
    }
}
