import SwiftUI

/// A place with its tab's mark, an optional caption under its name and an optional distance at the trailing edge.
/// At accessibility text sizes the distance moves under the name so the name is not truncated.
struct PlaceRow: View {
    let tab: MapTab
    let name: String
    var caption: String?
    var distance: Double?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            TabSymbol(tab: tab)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let caption {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if dynamicTypeSize.isAccessibilitySize, let distance {
                    distanceText(distance)
                }
            }
            Spacer(minLength: 8)
            if !dynamicTypeSize.isAccessibilitySize, let distance {
                distanceText(distance)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func distanceText(_ distance: Double) -> some View {
        Text(DistanceText.straightLine(distance))
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}

/// The results page of a tab: its places as a list, or why there is none yet.
struct ResultsPage: View {
    let tab: MapTab
    let state: SearchState
    let onOpen: (Place) -> Void
    let onRetry: () -> Void

    var body: some View {
        List {
            switch state {
            case .idle, .searching:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("検索中…")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("resultsSummary")
            case .loaded(let places):
                Section {
                    ForEach(places) { place in
                        Button {
                            onOpen(place)
                        } label: {
                            PlaceRow(tab: tab, name: place.name)
                        }
                        .tint(.primary)
                        .accessibilityIdentifier("place.\(place.id.rawValue)")
                    }
                } header: {
                    Text("\(places.count)件")
                        .accessibilityIdentifier("resultsSummary")
                } footer: {
                    if places.isEmpty {
                        Text("このエリアでは見つかりませんでした。地図を動かして「このエリアを検索」を試してください。")
                    }
                }
            case .throttled(let retryAt):
                Text("検索が混み合っています。\(retryAt.formatted(date: .omitted, time: .shortened))に自動で再検索します。")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("resultsSummary")
            case .failed(let message):
                Section {
                    Label("検索できませんでした", systemImage: "exclamationmark.triangle.fill")
                        .accessibilityIdentifier("resultsSummary")
                    Button("もう一度検索", systemImage: "arrow.clockwise", action: onRetry)
                } footer: {
                    Text(message)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

/// The place page of a tab: the place, and for every other tab that has results its nearest place with the
/// straight-line distance. Picking one shows it in its own tab.
struct PlacePageView: View {
    struct Nearest: Identifiable {
        let tab: MapTab
        let place: Place
        let distance: Double

        var id: TabID { tab.id }
    }

    let tab: MapTab
    let place: Place
    let nearest: [Nearest]
    let onJump: (Nearest) -> Void

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    TabSymbol(tab: tab)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(.title3.weight(.semibold))
                            .accessibilityIdentifier("placeTitle")
                        Text(tab.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                if nearest.isEmpty {
                    Text("ほかのタブに検索結果がありません")
                        .foregroundStyle(.secondary)
                }
                ForEach(nearest) { entry in
                    Button {
                        onJump(entry)
                    } label: {
                        PlaceRow(
                            tab: entry.tab, name: entry.place.name, caption: entry.tab.title, distance: entry.distance)
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("nearest.\(entry.tab.title)")
                }
            } header: {
                Text("ほかのタブで最も近い場所")
            } footer: {
                if !nearest.isEmpty {
                    Text("選ぶと、そのタブでその場所を開きます。")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

/// The presets to search with one tap, and the typed text as a query of its own.
struct SearchSuggestions: View {
    let text: String
    let onPick: (SearchQuery) -> Void

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        List {
            if !trimmed.isEmpty && SearchPreset.matching(trimmed) == nil {
                Section {
                    Button {
                        onPick(SearchQuery(text: trimmed))
                    } label: {
                        Label("「\(trimmed)」を検索", systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier("confirmQueryButton")
                }
            }
            Section {
                ForEach(SearchPreset.all.filter { trimmed.isEmpty || $0.name.contains(trimmed) }) { preset in
                    Button {
                        onPick(preset.query)
                    } label: {
                        Label {
                            Text(preset.name)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: preset.query.symbolName)
                        }
                    }
                    .accessibilityIdentifier("preset.\(preset.name)")
                }
            } header: {
                Text("よく使う検索")
            } footer: {
                Text("タブごとに別の地図で検索します。下のタブを長押しすると閉じられます。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}
