import CoreLocation

enum CurrentLocation {
    /// The user's location, or nil when it is denied or no fix arrives within the timeout.
    static func fetch(timeout: Duration = .seconds(5)) async -> Coordinate? {
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        return await withTaskGroup(of: Coordinate?.self) { group in
            group.addTask {
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let location = update.location {
                            return Coordinate(location.coordinate)
                        }
                        if update.authorizationDenied || update.authorizationDeniedGlobally
                            || update.authorizationRestricted
                        {
                            return nil
                        }
                    }
                } catch {
                    return nil
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next().flatMap { $0 }
            group.cancelAll()
            return first
        }
    }
}
