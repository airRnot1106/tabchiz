import Foundation
import MapKit

/// What survives a relaunch: each tab's query and color. A blank tab has no query. Results are searched again at
/// launch, and every map starts on the default area.
nonisolated struct SavedTab: Codable, Hashable, Sendable {
    let id: UUID
    let text: String?
    let category: String?
    let color: TabColor

    init(id: UUID = UUID(), query: SearchQuery?, color: TabColor) {
        self.id = id
        text = query?.text
        category = query?.category?.rawValue
        self.color = color
    }

    init(_ tab: MapTab) {
        self.init(id: tab.id.rawValue, query: tab.query, color: tab.color)
    }

    func tab(camera: CameraRegion) -> MapTab {
        let query = text.map {
            SearchQuery(text: $0, category: category.map(MKPointOfInterestCategory.init(rawValue:)))
        }
        return MapTab(id: TabID(rawValue: id), color: color, query: query, camera: camera)
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
