import Foundation
import MapKit

/// Answers from a bundled set of invented places, for UI tests and previews. Queries other than スーパー, ジム and
/// カフェ return no places. Each query has 25 places on a grid with rows 0.003 degrees of latitude apart and columns
/// 0.004 degrees of longitude apart. ジム sits 0.0012 degrees north of スーパー and カフェ sits between them. The
/// first two supermarkets are the exception: テストスーパー01 is at the grid's origin, テストジム01 is 0.0012 degrees
/// north of it and テストスーパー02 is a further 0.0007 degrees north.
nonisolated struct FixturePlaceSearcher: PlaceSearcher {
    private struct Item: Decodable {
        let id: String?
        let name: String
        let lat: Double
        let lon: Double
        let category: String?
    }

    private let placesByQuery: [String: [Place]]

    init(placesByQuery: [String: [Place]]) {
        self.placesByQuery = placesByQuery
    }

    init(bundle: Bundle = .main, resource: String = "fixture-places") {
        guard let url = bundle.url(forResource: resource, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let items = try? JSONDecoder().decode([String: [Item]].self, from: data)
        else {
            self.init(placesByQuery: [:])
            return
        }
        self.init(placesByQuery: items.mapValues { $0.map(Self.place(from:)) })
    }

    func search(_ query: SearchQuery, region: CameraRegion) async throws -> [Place] {
        placesByQuery[query.text] ?? []
    }

    private static func place(from item: Item) -> Place {
        let coordinate = Coordinate(latitude: item.lat, longitude: item.lon)
        return Place(
            id: PlaceID(appleIdentifier: item.id, name: item.name, coordinate: coordinate),
            name: item.name,
            coordinate: coordinate,
            category: item.category.map(MKPointOfInterestCategory.init(rawValue:))
        )
    }
}
