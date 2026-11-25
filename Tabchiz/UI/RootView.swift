import SwiftUI

/// A full-screen map with a sheet that always rests over it, as in Maps.
struct RootView: View {
    let store: BrowserStore
    let showsUserLocation: Bool

    @State private var detent: PresentationDetent = .medium

    var body: some View {
        GeometryReader { geometry in
            let insets = Insets(geometry: geometry, detent: detent)
            ZStack(alignment: .top) {
                MapCanvas(
                    content: MapContent(browser: store.browser),
                    camera: store.browser.activeTab.current.camera,
                    command: store.cameraCommand,
                    showsUserLocation: showsUserLocation,
                    controlInsets: UIEdgeInsets(insets.controls),
                    obscuredInsets: UIEdgeInsets(insets.obscured),
                    onOpen: { placeID, tabID in
                        showMap()
                        store.openPlace(placeID, in: tabID)
                    },
                    onJump: { placeID, tabID in
                        showMap()
                        store.jump(to: placeID, in: tabID)
                    },
                    onCameraChange: { store.cameraDidChange($0, in: $1) }
                )
                .ignoresSafeArea()

                if store.showsResearchButton {
                    researchButton
                }
            }
        }
        .sheet(isPresented: .constant(true)) {
            BrowserSheet(store: store, detent: $detent)
                .presentationDetents([.collapsed, .medium, .large], selection: $detent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled()
        }
        .task { await store.launch() }
    }

    private var researchButton: some View {
        Button {
            store.searchHere(in: store.browser.activeTab.id)
        } label: {
            Label("このエリアを検索", systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.glass)
        .padding(.top, 8)
        .accessibilityIdentifier("researchButton")
    }

    /// The place page shows next to the map, not over it.
    private func showMap() {
        if detent == .large {
            detent = .medium
        }
    }
}

/// Bands of the map covered by the status bar, the search-here button and the sheet, measured from the screen edges.
private struct Insets {
    /// The search-here button's band below the status bar.
    static let topBar: CGFloat = 56
    /// Gap between the Apple logo and the sheet at its lowest resting height.
    static let legalGap: CGFloat = 10

    let controls: EdgeInsets
    let obscured: EdgeInsets

    init(geometry: GeometryProxy, detent: PresentationDetent) {
        let safe = geometry.safeAreaInsets
        let screenHeight = geometry.size.height + safe.top + safe.bottom
        let collapsed = BrowserSheet.collapsedHeight + safe.bottom
        let sheet = detent == .collapsed ? collapsed : screenHeight / 2
        controls = EdgeInsets(top: safe.top, leading: 8, bottom: collapsed + Self.legalGap, trailing: 8)
        obscured = EdgeInsets(top: safe.top + Self.topBar, leading: 12, bottom: sheet, trailing: 12)
    }
}

extension UIEdgeInsets {
    fileprivate init(_ insets: EdgeInsets) {
        self.init(top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
    }
}

#Preview {
    let store = BrowserStore(
        searcher: FixturePlaceSearcher(),
        storage: UserDefaultsTabStorage(defaults: UserDefaults(suiteName: "preview") ?? .standard)
    )
    store.submit(SearchQuery(text: "スーパー"), in: store.browser.activeTab.id)
    return RootView(store: store, showsUserLocation: false)
}
