import SwiftUI

/// Pins a place, or unpins it when it is pinned.
struct PinToggle: View {
    let isPinned: Bool
    let action: () -> Void

    var body: some View {
        Button(isPinned ? "ピンを外す" : "ピンを刺す", systemImage: isPinned ? "pin.slash" : "pin", action: action)
            .accessibilityIdentifier("pinToggleButton")
    }
}

/// The pins of a tab as a list section. Nothing shows while the tab has no pin. A tap opens the pin's page, a
/// swipe removes the pin, and the context menu renames or removes it.
struct PinsSection: View {
    let tab: MapTab
    let onOpen: (Pin) -> Void
    let onRename: (Pin) -> Void
    let onRemove: (Pin) -> Void

    var body: some View {
        if !tab.pins.isEmpty {
            Section {
                ForEach(Array(tab.pins.enumerated()), id: \.element.id) { index, pin in
                    Button {
                        onOpen(pin)
                    } label: {
                        PlaceRow(tab: tab, name: pin.name, isPin: true)
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("pinRow.\(index)")
                    .swipeActions(edge: .trailing) {
                        Button("削除", systemImage: "trash", role: .destructive) {
                            onRemove(pin)
                        }
                        .accessibilityIdentifier("removePinSwipeAction")
                    }
                    .contextMenu {
                        Button("名前を変更", systemImage: "pencil") {
                            onRename(pin)
                        }
                        .accessibilityIdentifier("renamePinAction")
                        Button("ピンを削除", systemImage: "trash", role: .destructive) {
                            onRemove(pin)
                        }
                        .accessibilityIdentifier("removePinAction")
                    }
                }
            } header: {
                Text("ピン \(tab.pins.count)個")
                    .accessibilityIdentifier("pinsSummary")
            }
        }
    }
}

/// The nearest spot of another tab to the spot a page is about.
struct NearestEntry: Identifiable {
    let tab: MapTab
    let spot: Spot
    let distance: Double

    var id: TabID { tab.id }

    /// The matches with their tabs, in the order of the matches.
    static func entries(for matches: [NearestMatch], in browser: Browser) -> [Self] {
        matches.compactMap { match in
            browser.tab(match.tabID).map { Self(tab: $0, spot: match.spot, distance: match.distance) }
        }
    }
}

/// For every other tab that has pins or results, its nearest spot with the straight-line distance. Picking one
/// shows it in its own tab.
struct NearestSection: View {
    let entries: [NearestEntry]
    let onJump: (NearestEntry) -> Void

    var body: some View {
        Section {
            if entries.isEmpty {
                Text("ほかのタブにピンも検索結果もありません")
                    .foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                Button {
                    onJump(entry)
                } label: {
                    PlaceRow(
                        tab: entry.tab,
                        name: entry.spot.name,
                        caption: entry.tab.title,
                        distance: entry.distance,
                        isPin: entry.isPin
                    )
                }
                .tint(.primary)
                .accessibilityIdentifier("nearest.\(entry.tab.title)")
            }
        } header: {
            Text("ほかのタブで最も近い場所")
        } footer: {
            if !entries.isEmpty {
                Text("選ぶと、そのタブでその場所を開きます。")
            }
        }
    }
}

extension NearestEntry {
    var isPin: Bool {
        if case .pin = spot { true } else { false }
    }
}

/// The pin page of a tab: the pin, for every other tab its nearest spot with the straight-line distance, and the
/// buttons that rename and remove the pin.
struct PinPageView: View {
    let tab: MapTab
    let pin: Pin
    let nearest: [NearestEntry]
    let onJump: (NearestEntry) -> Void
    let onRename: () -> Void
    let onRemove: () -> Void

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    SpotSymbol(systemName: "mappin", color: tab.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pin.name)
                            .font(.title3.weight(.semibold))
                            .accessibilityIdentifier("pinTitle")
                        Text(pin.origin == .dropped ? "地図に刺したピン" : "検索結果に刺したピン")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            NearestSection(entries: nearest, onJump: onJump)
            Section {
                Button("名前を変更", systemImage: "pencil", action: onRename)
                    .accessibilityIdentifier("renamePinButton")
                Button("ピンを削除", systemImage: "trash", role: .destructive, action: onRemove)
                    .accessibilityIdentifier("removePinButton")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}
