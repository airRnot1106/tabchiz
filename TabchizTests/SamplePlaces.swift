import Foundation

@testable import Tabchiz

/// Invented places on a small grid, so every distance the tests expect can be worked out by hand. Each place sits
/// straight north or south of `market` where a test reads its distance, and 0.0001 degrees of latitude is
/// 6 371 008.8 m × π / 180 × 0.0001 = 11.1195 m on a sphere of the mean Earth radius.
enum SamplePlaces {
    static let market = place("sample-supermarket-a", "テストスーパーA", 35.6750, 139.7250)
    /// 0.0012 degrees north of `market`: 133.43 m.
    static let nearGym = place("sample-gym-a", "テストジムA", 35.6762, 139.7250)
    /// 0.0018 degrees north of `market`: 200.15 m.
    static let nextGym = place("sample-gym-b", "テストジムB", 35.6768, 139.7250)
    static let farGym = place("sample-gym-c", "テストジムC", 35.6810, 139.7250)
    static let southGym = place("sample-gym-d", "テストジムD", 35.6720, 139.7210)
    static let cafeA = place("sample-cafe-a", "テストカフェA", 35.6760, 139.7270)
    static let cafeB = place("sample-cafe-b", "テストカフェB", 35.6765, 139.7265)

    static let gyms = [farGym, southGym, nextGym, nearGym]
    static let cafes = [cafeA, cafeB]

    static func place(_ id: String, _ name: String, _ latitude: Double, _ longitude: Double) -> Place {
        Place(
            id: PlaceID(rawValue: id),
            name: name,
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            category: nil
        )
    }

    /// Great-circle distance on a sphere of the mean Earth radius, independent of CLLocation.
    static func haversine(_ origin: Place, _ target: Place) -> Double {
        let radius = 6_371_008.8
        let lat1 = origin.coordinate.latitude * .pi / 180
        let lat2 = target.coordinate.latitude * .pi / 180
        let deltaLat = lat2 - lat1
        let deltaLon = (target.coordinate.longitude - origin.coordinate.longitude) * .pi / 180
        let term = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * radius * asin(term.squareRoot())
    }
}
