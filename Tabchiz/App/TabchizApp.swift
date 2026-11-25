import SwiftUI

@main
struct TabchizApp: App {
    private let environment = AppEnvironment()
    @State private var store: BrowserStore

    init() {
        _store = State(initialValue: environment.makeStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, showsUserLocation: !environment.usesFixture)
        }
    }
}
