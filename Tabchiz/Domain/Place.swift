import CoreLocation
import MapKit

nonisolated struct Coordinate: Hashable, Sendable, Codable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(to other: Coordinate) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

nonisolated struct PlaceID: Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Apple's identifier when MapKit gives one. Otherwise the name plus the coordinate rounded to 1e-5 degrees,
    /// which is about 1 m, so the same unidentified place found twice gets the same ID.
    init(appleIdentifier: String?, name: String, coordinate: Coordinate) {
        if let appleIdentifier, !appleIdentifier.isEmpty {
            rawValue = appleIdentifier
        } else {
            let lat = (coordinate.latitude * 100_000).rounded() / 100_000
            let lon = (coordinate.longitude * 100_000).rounded() / 100_000
            rawValue = "derived:\(name)@\(lat),\(lon)"
        }
    }
}

nonisolated struct Place: Hashable, Sendable, Identifiable {
    let id: PlaceID
    let name: String
    let coordinate: Coordinate
    let category: MKPointOfInterestCategory?
}

extension Array where Element == Place {
    /// Keeps the first place for each ID, in the original order.
    nonisolated func dedupedByID() -> [Place] {
        var seen = Set<PlaceID>()
        return filter { seen.insert($0.id).inserted }
    }
}
