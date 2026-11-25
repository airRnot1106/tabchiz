import Foundation

nonisolated protocol PlaceSearcher: Sendable {
    func search(_ query: SearchQuery, region: CameraRegion) async throws -> [Place]
}

nonisolated enum PlaceSearchError: Error, Equatable {
    /// MapKit refused the request because the app sent too many in the last minute.
    case throttled
}
