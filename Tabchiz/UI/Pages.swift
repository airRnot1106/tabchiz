import SwiftUI

/// A place with its tab's mark, or a pin with the pin mark in its tab's color. An optional caption and an
/// optional straight-line distance show under the name, so the name keeps the row's width and two rows of nearest
/// spots fit in the half-height sheet.
struct PlaceRow: View {
    let tab: MapTab
    let name: String
    var caption: String?
    var distance: Double?
    var isPin = false

    var body: some View {
        HStack(spacing: 12) {
            SpotSymbol(systemName: isPin ? "mappin" : tab.symbolName, color: tab.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .foregroundStyle(.primary)
                if caption != nil || distance != nil {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { details }
                        VStack(alignment: .leading, spacing: 2) { details }
                    }
                }
            }
            Spacer(minLength: 8)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var details: some View {
        if let caption {
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        if let distance {
            Text(DistanceText.straightLine(distance))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }
}

/// The results page of a tab: its pins, then its places as a list, or why there is none yet. A place is pinned
/// or unpinned from its row by a swipe or its context menu.
struct ResultsPage: View {
    let tab: MapTab
    let state: SearchState
    let pins: PinsSection
    let onOpen: (Place) -> Void
    let onTogglePin: (Place) -> Void
    let onRetry: () -> Void

    var body: some View {
        List {
            pins
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
                        row(place)
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

    private func row(_ place: Place) -> some View {
        let isPinned = tab.pin(for: place.id) != nil
        return Button {
            onOpen(place)
        } label: {
            HStack(spacing: 8) {
                PlaceRow(tab: tab, name: place.name)
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.footnote)
                        .foregroundStyle(tab.color.color)
                        .accessibilityHidden(true)
                }
            }
        }
        .tint(.primary)
        .accessibilityValue(isPinned ? "ピン済み" : "")
        .accessibilityIdentifier("place.\(place.id.rawValue)")
        .swipeActions(edge: .trailing) {
            PinToggle(isPinned: isPinned) { onTogglePin(place) }
                .tint(tab.color.color)
        }
        .contextMenu {
            PinToggle(isPinned: isPinned) { onTogglePin(place) }
        }
    }
}

/// The place page of a tab: the place, a button that pins or unpins it, and for every other tab its nearest spot
/// with the straight-line distance.
struct PlacePageView: View {
    let tab: MapTab
    let place: Place
    let nearest: [NearestEntry]
    let onTogglePin: () -> Void
    let onJump: (NearestEntry) -> Void

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    SpotSymbol(systemName: tab.symbolName, color: tab.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(.title3.weight(.semibold))
                            .accessibilityIdentifier("placeTitle")
                        Text(tab.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                PinToggle(isPinned: tab.pin(for: place.id) != nil, action: onTogglePin)
            }
            NearestSection(entries: nearest, onJump: onJump)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

/// The presets to search with one tap, and the typed text as a query of its own. A blank tab shows its pins above
/// them.
struct SearchSuggestions: View {
    let text: String
    /// The tab's pins above the presets, on a blank tab.
    var pins: PinsSection?
    let onPick: (SearchQuery) -> Void

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        List {
            if let pins {
                pins
            }
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
                Text("タブごとに別の地図で検索します。地図を長押しするとピンを刺せます。下のタブを長押しすると閉じられます。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}
