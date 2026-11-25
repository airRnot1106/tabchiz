import Foundation

/// Counts search requests in a sliding window. MapKit starts rejecting requests at about 50 per 60 s, so the app
/// stops itself at that rate and knows when the next request is allowed.
actor RequestBudget {
    nonisolated enum Decision: Equatable, Sendable {
        case granted
        case denied(retryAt: Date)
    }

    private let limit: Int
    private let window: TimeInterval
    private let now: @Sendable () -> Date
    private var grantedAt: [Date] = []

    init(limit: Int = 50, window: TimeInterval = 60, now: @escaping @Sendable () -> Date = { Date() }) {
        self.limit = limit
        self.window = window
        self.now = now
    }

    func reserve() -> Decision {
        let current = now()
        grantedAt.removeAll { $0.addingTimeInterval(window) <= current }
        guard grantedAt.count < limit else {
            return .denied(retryAt: grantedAt[0].addingTimeInterval(window))
        }
        grantedAt.append(current)
        return .granted
    }
}
