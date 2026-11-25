import Foundation

nonisolated struct PinID: Hashable, Sendable, Codable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// A spot the user marked in a tab. It stays until the user removes it, whatever the tab searches or shows.
nonisolated struct Pin: Hashable, Sendable, Identifiable {
    nonisolated enum Origin: Hashable, Sendable {
        /// Dropped on the map by a long press.
        case dropped
        /// Pinned from a search result.
        case place(PlaceID)
    }

    let id: PinID
    var name: String
    let coordinate: Coordinate
    let origin: Origin

    /// The name of a dropped pin until its address arrives: "ピン N".
    static func defaultName(_ number: Int) -> String {
        "ピン \(number)"
    }
}

/// A pin together with the tab that holds it.
nonisolated struct PinRef: Hashable, Sendable {
    let tabID: TabID
    let pinID: PinID
}

/// Something a tab puts on its map: a search result or a pin.
nonisolated enum Spot: Hashable, Sendable {
    case place(Place)
    case pin(Pin)

    var name: String {
        switch self {
        case .place(let place): place.name
        case .pin(let pin): pin.name
        }
    }

    var coordinate: Coordinate {
        switch self {
        case .place(let place): place.coordinate
        case .pin(let pin): pin.coordinate
        }
    }
}
