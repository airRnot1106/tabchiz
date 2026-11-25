import MapKit

/// A north-up map area in degrees. It describes what a map shows and what a search covers. It has no heading, so
/// the maps do not rotate.
nonisolated struct CameraRegion: Hashable, Sendable {
    var center: Coordinate
    var latitudeDelta: Double
    var longitudeDelta: Double

    static let defaultArea = Self(
        center: Coordinate(latitude: 35.6740, longitude: 139.7220),
        latitudeDelta: 0.02,
        longitudeDelta: 0.02
    )

    init(center: Coordinate, latitudeDelta: Double, longitudeDelta: Double) {
        self.center = center
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }

    init(_ region: MKCoordinateRegion) {
        self.init(
            center: Coordinate(region.center),
            latitudeDelta: region.span.latitudeDelta,
            longitudeDelta: region.span.longitudeDelta
        )
    }

    var mkRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center.clCoordinate,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    /// True when `camera` has left this searched region far enough that its results no longer describe what the
    /// map shows: the center moved by more than a quarter of the span, or the map zoomed out by more than 2x.
    /// Zooming in stays inside the searched region, so it never asks for a new search.
    func needsResearch(for camera: Self) -> Bool {
        let latShift = abs(camera.center.latitude - center.latitude) / latitudeDelta
        let lonShift = abs(camera.center.longitude - center.longitude) / longitudeDelta
        let zoom = camera.latitudeDelta / latitudeDelta
        return latShift > 0.25 || lonShift > 0.25 || zoom > 2
    }
}
