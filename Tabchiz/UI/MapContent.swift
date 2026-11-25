import Foundation

/// Everything the map on screen draws, derived from the browser. The map rebuilds its annotations only when this
/// changes.
struct MapContent: Equatable {
    enum Role: Equatable {
        /// A place of the tab on screen while no place is viewed.
        case normal
        /// The place the tab views: marker with a name label that always shows.
        case selected
        /// The nearest place of another tab to the viewed place, with its straight-line distance.
        case nearest(distance: Double)
        /// Any other place of the tab while a place is viewed.
        case dimmed
        /// A place of any tab in the overview: a dot in its tab's color that clusters only with its own tab.
        case overview
    }

    struct Pin: Equatable, Identifiable {
        let tabID: TabID
        /// The tab's position in the bar.
        let tabIndex: Int
        let tabName: String
        let symbolName: String
        let color: TabColor
        let place: Place
        let role: Role

        var id: String { "\(tabID.rawValue.uuidString)/\(place.id.rawValue)" }

        init(_ place: Place, of tab: MapTab, at tabIndex: Int, role: Role) {
            tabID = tab.id
            self.tabIndex = tabIndex
            tabName = tab.title
            symbolName = tab.symbolName
            color = tab.color
            self.place = place
            self.role = role
        }
    }

    struct Line: Equatable {
        let origin: Coordinate
        let target: Coordinate
        let color: TabColor
    }

    let scene: MapScene
    let pins: [Pin]
    let lines: [Line]

    init(browser: Browser) {
        scene = browser.mode.scene
        let indexed = Array(browser.tabs.enumerated())
        guard case .tab(let id) = browser.mode, let (index, tab) = indexed.first(where: { $0.element.id == id })
        else {
            pins = indexed.flatMap { index, tab in
                tab.places.map { Pin($0, of: tab, at: index, role: .overview) }
            }
            lines = []
            return
        }
        guard let viewed = tab.viewedPlace else {
            pins = tab.places.map { Pin($0, of: tab, at: index, role: .normal) }
            lines = []
            return
        }
        let nearest = browser.nearestToViewedPlace(in: id).compactMap { match in
            indexed.first { $0.element.id == match.tabID }.map { (match: match, index: $0.offset, tab: $0.element) }
        }
        pins =
            tab.places.map { Pin($0, of: tab, at: index, role: $0.id == viewed.id ? .selected : .dimmed) }
            + nearest.map {
                Pin($0.match.place, of: $0.tab, at: $0.index, role: .nearest(distance: $0.match.distance))
            }
        lines = nearest.map { Line(origin: viewed.coordinate, target: $0.match.place.coordinate, color: $0.tab.color) }
    }
}
