import CoreLocation

nonisolated struct NearestMatch: Hashable, Sendable {
    let tabID: TabID
    let spot: Spot
    let distance: CLLocationDistance
}

/// The candidate with the shortest straight-line distance to `coordinate`. Of two equally near candidates the
/// earlier one wins.
nonisolated func nearestSpot(
    to coordinate: Coordinate,
    in candidates: [Spot]
) -> (spot: Spot, distance: CLLocationDistance)? {
    candidates
        .map { (spot: $0, distance: coordinate.distance(to: $0.coordinate)) }
        .min { $0.distance < $1.distance }
}

/// The nearest spot of each tab other than `viewedTab`, in tab order: the nearest among the tab's pins and its
/// loaded results together. Tabs with neither are left out.
nonisolated func nearestMatches(
    from coordinate: Coordinate,
    excluding viewedTab: TabID,
    in tabs: [MapTab]
) -> [NearestMatch] {
    tabs.compactMap { tab in
        guard tab.id != viewedTab, let nearest = nearestSpot(to: coordinate, in: tab.spots) else { return nil }
        return NearestMatch(tabID: tab.id, spot: nearest.spot, distance: nearest.distance)
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
