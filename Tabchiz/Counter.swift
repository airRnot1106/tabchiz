import Observation

@Observable
final class Counter {
    private(set) var count = 0

    func increment() {
        count += 1
    }

    func reset() {
        count = 0
    }
}
