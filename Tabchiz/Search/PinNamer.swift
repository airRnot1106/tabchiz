import CoreLocation
import MapKit
import Synchronization

/// Finds a name for the spot where a pin was dropped.
nonisolated protocol PinNamer: Sendable {
    /// Nil when the spot has no name or the lookup fails.
    func name(at coordinate: Coordinate) async -> String?
}

/// Names a spot by Apple Maps' address for it: the short address, such as "テスト町1丁目1-3", or the name of the
/// map item when it has no short address.
nonisolated struct MapKitPinNamer: PinNamer {
    func name(at coordinate: Coordinate) async -> String? {
        await Self.lookUp(coordinate)
    }

    @MainActor
    private static func lookUp(_ coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location),
            let item = try? await request.mapItems.first
        else { return nil }
        return [item.address?.shortAddress, item.name, item.address?.fullAddress]
            .compactMap(\.self)
            .first { !$0.isEmpty }
    }
}

/// Names spots "テスト地点 1", "テスト地点 2" and so on in the order they are asked for, for UI tests and previews.
nonisolated final class FixturePinNamer: PinNamer {
    private let count = Mutex(0)

    func name(at coordinate: Coordinate) async -> String? {
        let number = count.withLock { count in
            count += 1
            return count
        }
        return "テスト地点 \(number)"
    }
}
