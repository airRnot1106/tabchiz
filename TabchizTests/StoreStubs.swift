import Foundation
import MapKit
import Synchronization

@testable import Tabchiz

@MainActor
final class MemoryStorage: TabStorage {
    var saved: [SavedTab]

    init(_ saved: [SavedTab] = []) {
        self.saved = saved
    }

    func load() -> [SavedTab] { saved }
    func save(_ tabs: [SavedTab]) { saved = tabs }
}

/// Answers from a table after an optional delay per query. Throws MapKit throttling for the first
/// `throttledCalls` requests. Records the region of every request.
nonisolated final class StubSearcher: PlaceSearcher {
    private let results: [String: [Place]]
    private let delays: [String: Duration]
    private let remainingThrottles: Mutex<Int>
    private let requested = Mutex<[CameraRegion]>([])

    init(results: [String: [Place]], delays: [String: Duration] = [:], throttledCalls: Int = 0) {
        self.results = results
        self.delays = delays
        remainingThrottles = Mutex(throttledCalls)
    }

    var regions: [CameraRegion] { requested.withLock { $0 } }

    func search(_ query: SearchQuery, region: CameraRegion) async throws -> [Place] {
        requested.withLock { $0.append(region) }
        if let delay = delays[query.text] {
            try await Task.sleep(for: delay)
        }
        let throttled = remainingThrottles.withLock { remaining in
            defer { remaining = max(remaining - 1, 0) }
            return remaining > 0
        }
        if throttled {
            throw PlaceSearchError.throttled
        }
        return results[query.text] ?? []
    }
}

/// Names every spot `name` after an optional delay, or finds no name when `name` is nil. Records the spots it
/// was asked about.
nonisolated final class StubNamer: PinNamer {
    private let name: String?
    private let delay: Duration?
    private let requested = Mutex<[Coordinate]>([])

    init(_ name: String? = nil, delay: Duration? = nil) {
        self.name = name
        self.delay = delay
    }

    var coordinates: [Coordinate] { requested.withLock { $0 } }

    func name(at coordinate: Coordinate) async -> String? {
        requested.withLock { $0.append(coordinate) }
        if let delay {
            try? await Task.sleep(for: delay)
        }
        return name
    }
}
