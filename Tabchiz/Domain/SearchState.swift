import Foundation

nonisolated enum SearchState: Hashable, Sendable {
    case idle
    case searching
    case loaded([Place])
    case throttled(retryAt: Date)
    case failed(message: String)

    var places: [Place] {
        if case .loaded(let places) = self { places } else { [] }
    }
}
