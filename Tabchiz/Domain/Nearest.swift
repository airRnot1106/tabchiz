import CoreLocation

nonisolated struct NearestMatch: Hashable, Sendable {
    let tabID: TabID
    let place: Place
    let distance: CLLocationDistance
}

/// The candidate with the shortest straight-line distance to `place`.
nonisolated func nearestPlace(
    to place: Place,
    in candidates: [Place]
) -> (place: Place, distance: CLLocationDistance)? {
    nearestPlace(to: place.coordinate, in: candidates)
}

nonisolated func nearestPlace(
    to coordinate: Coordinate,
    in candidates: [Place]
) -> (place: Place, distance: CLLocationDistance)? {
    candidates
        .map { (place: $0, distance: coordinate.distance(to: $0.coordinate)) }
        .min { $0.distance < $1.distance }
}

/// The nearest place of each tab other than `viewedTab`, in tab order. Tabs without results are left out.
nonisolated func nearestMatches(
    from place: Place,
    excluding viewedTab: TabID,
    in tabs: [MapTab]
) -> [NearestMatch] {
    tabs.compactMap { tab in
        guard tab.id != viewedTab, let nearest = nearestPlace(to: place, in: tab.places) else { return nil }
        return NearestMatch(tabID: tab.id, place: nearest.place, distance: nearest.distance)
    }
}

nonisolated enum DistanceText {
    /// "133 m" below 1 km, "1.2 km" from 1 km.
    static func short(_ meters: CLLocationDistance) -> String {
        if meters < 999.5 {
            return "\(Int(meters.rounded())) m"
        }
        return String(format: "%.1f km", meters / 1000)
    }

    static func straightLine(_ meters: CLLocationDistance) -> String {
        "直線 \(short(meters))"
    }
}
