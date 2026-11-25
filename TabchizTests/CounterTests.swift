import Testing

@testable import Tabchiz

struct CounterTests {
    @Test func incrementAddsOne() {
        let counter = Counter()
        counter.increment()
        counter.increment()
        #expect(counter.count == 2)
    }

    @Test func resetReturnsToZero() {
        let counter = Counter()
        counter.increment()
        counter.reset()
        #expect(counter.count == 0)
    }
}
