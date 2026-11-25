import SwiftUI

/// What the sheet shows for the tab on screen under the search field: the search suggestions while a query is
/// typed, otherwise the tab's page.
struct TabPage: View {
    let store: BrowserStore
    let tab: MapTab
    /// The text being typed, or nil while nobody types.
    let typed: String?
    let onSearch: (SearchQuery) -> Void
    /// Brings the map back into view before the page of one spot shows.
    let showMap: () -> Void

    /// The pin being renamed, with the name as typed so far.
    @State private var renamed: Pin?
    @State private var nameDraft = ""

    var body: some View {
        page
            .alert(
                "ピンの名前",
                isPresented: Binding(get: { renamed != nil }, set: { if !$0 { renamed = nil } }),
                presenting: renamed
            ) { pin in
                TextField("名前", text: $nameDraft)
                Button("保存") {
                    store.renamePin(PinRef(tabID: tab.id, pinID: pin.id), to: nameDraft)
                }
                Button("キャンセル", role: .cancel) {}
            }
    }

    @ViewBuilder private var page: some View {
        if let typed {
            SearchSuggestions(text: typed, onPick: onSearch)
        } else {
            switch tab.current.page {
            case .blank:
                SearchSuggestions(text: "", pins: pins, onPick: onSearch)
            case .results(_, let state):
                ResultsPage(
                    tab: tab,
                    state: state,
                    pins: pins,
                    onOpen: { place in
                        showMap()
                        store.openPlace(place.id, in: tab.id)
                    },
                    onTogglePin: togglePin,
                    onRetry: { store.searchHere(in: tab.id) }
                )
            case .place(let shown):
                PlacePageView(
                    tab: tab,
                    place: shown.place,
                    nearest: nearest,
                    onTogglePin: { togglePin(shown.place) },
                    onJump: jump
                )
            case .pin:
                if let pin = tab.viewedPin {
                    PinPageView(
                        tab: tab,
                        pin: pin,
                        nearest: nearest,
                        onJump: jump,
                        onRename: { rename(pin) },
                        onRemove: { remove(pin) }
                    )
                }
            }
        }
    }

    private var pins: PinsSection {
        PinsSection(
            tab: tab,
            onOpen: { pin in
                showMap()
                store.openPin(PinRef(tabID: tab.id, pinID: pin.id))
            },
            onRename: rename,
            onRemove: remove
        )
    }

    private var nearest: [NearestEntry] {
        NearestEntry.entries(for: store.browser.nearestToViewedSpot(in: tab.id), in: store.browser)
    }

    private func jump(_ entry: NearestEntry) {
        showMap()
        store.jump(to: entry.spot, in: entry.tab.id)
    }

    private func togglePin(_ place: Place) {
        if let pin = tab.pin(for: place.id) {
            remove(pin)
        } else {
            store.pinPlace(place.id, in: tab.id)
        }
    }

    private func rename(_ pin: Pin) {
        nameDraft = pin.name
        renamed = pin
    }

    private func remove(_ pin: Pin) {
        store.removePin(PinRef(tabID: tab.id, pinID: pin.id))
    }
}
