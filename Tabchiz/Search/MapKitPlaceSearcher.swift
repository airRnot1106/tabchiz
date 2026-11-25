import MapKit

/// Searches Apple Maps points of interest inside the region. MapKit returns at most 25 results per request.
nonisolated struct MapKitPlaceSearcher: PlaceSearcher {
    func search(_ query: SearchQuery, region: CameraRegion) async throws -> [Place] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query.text
        request.region = region.mkRegion
        request.resultTypes = .pointOfInterest
        request.regionPriority = .required
        if let category = query.category {
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])
        }
        let response: MKLocalSearch.Response
        do {
            response = try await MKLocalSearch(request: request).start()
        } catch let error as MKError where error.code == .loadingThrottled {
            throw PlaceSearchError.throttled
        } catch let error as MKError where error.code == .placemarkNotFound {
            return []
        }
        return Self.places(from: response.mapItems)
    }

    /// Converts map items and drops an item whose identifier or alternate identifier was already seen, because
    /// MapKit can return one place under two identifiers.
    static func places(from items: [MKMapItem]) -> [Place] {
        var seen = Set<String>()
        var places: [Place] = []
        for item in items {
            let identifiers = ([item.identifier] + item.alternateIdentifiers).compactMap { $0?.rawValue }
            guard seen.isDisjoint(with: identifiers) else { continue }
            seen.formUnion(identifiers)
            let coordinate = Coordinate(item.location.coordinate)
            let name = item.name ?? ""
            places.append(
                Place(
                    id: PlaceID(appleIdentifier: item.identifier?.rawValue, name: name, coordinate: coordinate),
                    name: name,
                    coordinate: coordinate,
                    category: item.pointOfInterestCategory
                )
            )
        }
        return places.dedupedByID()
    }
}
