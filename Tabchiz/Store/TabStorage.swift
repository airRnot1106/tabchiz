import Foundation
import MapKit

/// A pin as it is saved. A pin cannot be searched again, so everything about it is kept.
nonisolated struct SavedPin: Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    /// The search result the pin was made from. Nil for a pin dropped on the map.
    let placeID: String?

    init(_ pin: Pin) {
        id = pin.id.rawValue
        name = pin.name
        latitude = pin.coordinate.latitude
        longitude = pin.coordinate.longitude
        if case .place(let placeID) = pin.origin {
            self.placeID = placeID.rawValue
        } else {
            placeID = nil
        }
    }

    var pin: Pin {
        Pin(
            id: PinID(rawValue: id),
            name: name,
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            origin: placeID.map { .place(PlaceID(rawValue: $0)) } ?? .dropped
        )
    }
}

/// What survives a relaunch: each tab's query, color and pins. A blank tab has no query. Results are searched
/// again at launch, and every map starts on the default area.
nonisolated struct SavedTab: Codable, Hashable, Sendable {
    let id: UUID
    let text: String?
    let category: String?
    let color: TabColor
    let pins: [SavedPin]

    init(id: UUID = UUID(), query: SearchQuery?, color: TabColor, pins: [SavedPin] = []) {
        self.id = id
        text = query?.text
        category = query?.category?.rawValue
        self.color = color
        self.pins = pins
    }

    init(_ tab: MapTab) {
        self.init(id: tab.id.rawValue, query: tab.query, color: tab.color, pins: tab.pins.map(SavedPin.init))
    }

    /// Tabs saved before pins existed have no `pins` key and load without pins.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        color = try container.decode(TabColor.self, forKey: .color)
        pins = try container.decodeIfPresent([SavedPin].self, forKey: .pins) ?? []
    }

    func tab(camera: CameraRegion) -> MapTab {
        let query = text.map {
            SearchQuery(text: $0, category: category.map(MKPointOfInterestCategory.init(rawValue:)))
        }
        return MapTab(id: TabID(rawValue: id), color: color, query: query, camera: camera, pins: pins.map(\.pin))
    }
}

protocol TabStorage {
    func load() -> [SavedTab]
    func save(_ tabs: [SavedTab])
}

/// Tabs saved by the layer version of the app, which also stored a visibility flag, load as ordinary tabs.
struct UserDefaultsTabStorage: TabStorage {
    let defaults: UserDefaults
    let key = "savedTabs.v1"

    func load() -> [SavedTab] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SavedTab].self, from: data)) ?? []
    }

    func save(_ tabs: [SavedTab]) {
        guard let data = try? JSONEncoder().encode(tabs) else { return }
        defaults.set(data, forKey: key)
    }
}
