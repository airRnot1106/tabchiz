import Foundation
import Synchronization
import Testing

@testable import Tabchiz

struct RequestBudgetTests {
    nonisolated final class TestClock: Sendable {
        private let current = Mutex(Date(timeIntervalSinceReferenceDate: 0))

        var now: Date { current.withLock { $0 } }

        func advance(by seconds: TimeInterval) {
            current.withLock { $0 = $0.addingTimeInterval(seconds) }
        }
    }

    @Test func fiftyRequestsInAMinuteAreAllowedAndTheFiftyFirstWaitsForTheOldest() async {
        let clock = TestClock()
        let start = clock.now
        let budget = RequestBudget(limit: 50, window: 60) { clock.now }

        var granted = 0
        for _ in 0..<50 {
            if await budget.reserve() == .granted {
                granted += 1
            }
            clock.advance(by: 0.5)
        }
        let fiftyFirst = await budget.reserve()

        #expect(granted == 50)
        #expect(fiftyFirst == .denied(retryAt: start.addingTimeInterval(60)))
    }

    @Test func aRequestIsAllowedAgainOnceTheOldestLeavesTheWindow() async {
        let clock = TestClock()
        let budget = RequestBudget(limit: 50, window: 60) { clock.now }
        for _ in 0..<50 {
            _ = await budget.reserve()
        }
        clock.advance(by: 10)
        let duringWindow = await budget.reserve()

        clock.advance(by: 50)
        let afterWindow = await budget.reserve()
        let nextAfterWindow = await budget.reserve()

        #expect(duringWindow == .denied(retryAt: Date(timeIntervalSinceReferenceDate: 60)))
        #expect(afterWindow == .granted)
        #expect(nextAfterWindow == .granted)
    }

    @Test func deniedRequestsDoNotUseTheBudget() async {
        let clock = TestClock()
        let budget = RequestBudget(limit: 1, window: 60) { clock.now }
        _ = await budget.reserve()
        for _ in 0..<10 {
            _ = await budget.reserve()
        }

        clock.advance(by: 60)

        #expect(await budget.reserve() == .granted)
    }
}
