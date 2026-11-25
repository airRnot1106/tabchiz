import CoreLocation

/// What Core Location reports while the app waits for the user's location.
enum LocationSignal: Sendable, Equatable {
    case fix(Coordinate)
    /// The permission prompt is on screen.
    case awaitingAuthorization
    case denied
    /// Permission is decided and no fix has arrived yet.
    case noFix
}

enum CurrentLocation {
    private enum Step {
        case signal(LocationSignal)
        case ended
        case timedOut(generation: Int)
    }

    /// The user's location, or nil when it is denied or no fix arrives within the timeout.
    static func fetch(timeout: Duration = .seconds(5)) async -> Coordinate? {
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        let signals = CLLocationUpdate.liveUpdates().map { update -> LocationSignal in
            if let location = update.location {
                return .fix(Coordinate(location.coordinate))
            }
            if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                return .denied
            }
            if update.authorizationRequestInProgress {
                return .awaitingAuthorization
            }
            return .noFix
        }
        return await firstFix(in: signals, timeout: timeout)
    }

    /// The first fix in `signals`, or nil on denial, on the end of `signals`, or when no fix arrives within
    /// `timeout`. The timeout does not run while the permission prompt is on screen.
    static func firstFix<Signals: AsyncSequence & Sendable>(
        in signals: Signals,
        timeout: Duration
    ) async -> Coordinate? where Signals.Element == LocationSignal {
        let (steps, input) = AsyncStream.makeStream(of: Step.self)
        let reader = Task {
            do {
                for try await signal in signals {
                    input.yield(.signal(signal))
                }
            } catch {}
            input.yield(.ended)
        }
        var timer: Task<Void, Never>?
        var generation = 0
        func startTimer() {
            generation += 1
            let current = generation
            timer = Task {
                try? await Task.sleep(for: timeout)
                input.yield(.timedOut(generation: current))
            }
        }
        defer {
            reader.cancel()
            timer?.cancel()
            input.finish()
        }
        startTimer()
        for await step in steps {
            switch step {
            case .signal(.fix(let coordinate)):
                return coordinate
            case .signal(.denied), .ended:
                return nil
            case .timedOut(let fired):
                if timer != nil, fired == generation {
                    return nil
                }
            case .signal(.awaitingAuthorization):
                timer?.cancel()
                timer = nil
            case .signal(.noFix):
                if timer == nil {
                    startTimer()
                }
            }
        }
        return nil
    }
}
