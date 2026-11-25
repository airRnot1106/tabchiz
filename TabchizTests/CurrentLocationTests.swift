import Testing

@testable import Tabchiz

struct CurrentLocationTests {
    let user = Coordinate(latitude: 35.7, longitude: 139.71)

    @Test func aFixAfterTheUserTakesLongerThanTheTimeoutToAnswerThePromptIsUsed() async throws {
        let (signals, input) = AsyncStream.makeStream(of: LocationSignal.self)
        input.yield(.awaitingAuthorization)
        let answer = Task {
            try await Task.sleep(for: .milliseconds(300))
            input.yield(.noFix)
            input.yield(.fix(user))
        }

        let located = await CurrentLocation.firstFix(in: signals, timeout: .milliseconds(100))

        try await answer.value
        #expect(located == user)
    }

    @Test func deniedPermissionGivesNoLocation() async {
        let (signals, input) = AsyncStream.makeStream(of: LocationSignal.self)
        input.yield(.awaitingAuthorization)
        input.yield(.denied)

        #expect(await CurrentLocation.firstFix(in: signals, timeout: .seconds(60)) == nil)
    }

    @Test func noFixWithinTheTimeoutAfterPermissionGivesNoLocation() async {
        let (signals, input) = AsyncStream.makeStream(of: LocationSignal.self)
        input.yield(.awaitingAuthorization)
        input.yield(.noFix)

        #expect(await CurrentLocation.firstFix(in: signals, timeout: .milliseconds(100)) == nil)
        input.finish()
    }

    @Test func silenceFromCoreLocationGivesNoLocationAfterTheTimeout() async {
        let (signals, input) = AsyncStream.makeStream(of: LocationSignal.self)

        #expect(await CurrentLocation.firstFix(in: signals, timeout: .milliseconds(100)) == nil)
        input.finish()
    }
}
