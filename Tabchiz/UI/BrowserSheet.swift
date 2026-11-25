import SwiftUI

extension PresentationDetent {
    /// Only the search field and the tab bar show.
    static let collapsed = Self.height(BrowserSheet.collapsedHeight)
}

/// The sheet that always rests over the map, as in Maps. From top to bottom: the search field of the tab on
/// screen with its back button and the new-tab button, the tab's page, and the tab bar. In the overview the search field and the page
/// give way to a list of the tabs.
struct BrowserSheet: View {
    private static let headerHeight: CGFloat = 72
    static let collapsedHeight = headerHeight + TabBar.height

    let store: BrowserStore
    @Binding var detent: PresentationDetent

    /// The text being typed. The search field shows the tab's query while nobody types.
    @State private var draft = ""
    @FocusState private var isEditing: Bool

    private var tab: MapTab { store.browser.activeTab }

    var body: some View {
        VStack(spacing: 0) {
            if store.browser.mode.scene == .overview {
                overviewHeader
                    .frame(height: Self.headerHeight, alignment: .bottom)
                OverviewPage(tabs: store.browser.tabs) { store.showTab($0.id) }
            } else {
                header
                    .frame(height: Self.headerHeight, alignment: .bottom)
                page
            }
            // The keyboard takes the bar's place while a query is typed.
            if !isEditing {
                TabBar(store: store)
            }
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                draft = tab.query?.text ?? ""
                detent = .large
            }
        }
        .onChange(of: store.browser.mode) {
            isEditing = false
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            if tab.canGoBack && !isEditing {
                Button {
                    store.back(in: tab.id)
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.fill.tertiary, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("戻る")
                .accessibilityIdentifier("backButton")
            }
            searchField
            if isEditing {
                Button("キャンセル") {
                    isEditing = false
                }
                .accessibilityIdentifier("cancelSearchButton")
            } else {
                newTabButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        // The header keeps its height, so the collapsed sheet always shows it whole.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var newTabButton: some View {
        Button {
            store.addTab()
        } label: {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.fill.tertiary, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!store.browser.canAddTab)
        .opacity(store.browser.canAddTab ? 1 : 0.4)
        .accessibilityLabel(store.browser.canAddTab ? "新規タブ" : "タブは\(Browser.maxTabs)個までです")
        .accessibilityIdentifier("newTabButton")
    }

    private var overviewHeader: some View {
        let tabs = store.browser.tabs
        return HStack(spacing: 8) {
            Label("全体", systemImage: "square.3.layers.3d")
                .font(.headline)
            Spacer()
            Text("\(tabs.count)タブ・\(tabs.map(\.places.count).reduce(0, +))件")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("overviewSummary")
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
        .padding(.bottom, 8)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                "スーパー、ジムなどを検索",
                text: Binding(
                    get: { isEditing ? draft : tab.query?.text ?? "" },
                    set: { draft = $0 }
                )
            )
            .focused($isEditing)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .onSubmit(commitDraft)
            .accessibilityIdentifier("searchField")
            if isEditing && !draft.isEmpty {
                Button {
                    draft = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("消去")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(.fill.tertiary, in: Capsule())
    }

    private func commitDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        commit(SearchQuery(text: text))
    }

    private func commit(_ query: SearchQuery) {
        store.submit(query, in: tab.id)
        isEditing = false
        detent = .medium
    }

    // MARK: Page

    @ViewBuilder private var page: some View {
        if isEditing {
            SearchSuggestions(text: draft, onPick: commit)
        } else {
            switch tab.current.page {
            case .blank:
                SearchSuggestions(text: "", onPick: commit)
            case .results(_, let state):
                ResultsPage(
                    tab: tab,
                    state: state,
                    onOpen: { place in
                        showMap()
                        store.openPlace(place.id, in: tab.id)
                    },
                    onRetry: { store.searchHere(in: tab.id) }
                )
            case .place(let shown):
                PlacePageView(
                    tab: tab,
                    place: shown.place,
                    nearest: store.browser.nearestToViewedPlace(in: tab.id).compactMap { match in
                        store.browser.tab(match.tabID).map {
                            PlacePageView.Nearest(tab: $0, place: match.place, distance: match.distance)
                        }
                    },
                    onJump: { entry in
                        showMap()
                        store.jump(to: entry.place.id, in: entry.tab.id)
                    }
                )
            }
        }
    }

    /// The map comes back into view when a place is picked from a full-height list.
    private func showMap() {
        if detent == .large {
            detent = .medium
        }
    }
}
