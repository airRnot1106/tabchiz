import SwiftUI

/// Which color is which tab, and how many pins each tab has, over the overview map.
struct OverviewLegend: View {
    let tabs: [MapTab]

    var body: some View {
        FlowLayout(spacing: 12, lineSpacing: 6) {
            ForEach(tabs) { tab in
                HStack(spacing: 5) {
                    Circle()
                        .fill(tab.color.color)
                        .frame(width: 10, height: 10)
                    Text(tab.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    if !tab.pins.isEmpty {
                        Label("\(tab.pins.count)", systemImage: "mappin")
                            .labelStyle(.titleAndIcon)
                            .labelIconToTitleSpacing(1)
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        // Kept at map label sizes so the legend does not cover the map.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "凡例 " + tabs.map { $0.pins.isEmpty ? $0.title : "\($0.title) ピン\($0.pins.count)個" }.joined(separator: "、")
        )
        .accessibilityIdentifier("overviewLegend")
    }
}

/// The tabs as a list with their result and pin counts. Picking one leaves the overview for that tab.
struct OverviewPage: View {
    let tabs: [MapTab]
    let onPick: (MapTab) -> Void

    var body: some View {
        List {
            Section {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    Button {
                        onPick(tab)
                    } label: {
                        PlaceRow(tab: tab, name: tab.title, caption: caption(tab))
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("overviewRow.\(index)")
                }
            } footer: {
                Text(
                    "ピンをタップすると、ほかのタブで最も近い場所までの距離を表示します。点をタップすると、そのタブでその場所を開きます。数字をタップすると、そのタブでその周辺を表示します。"
                )
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func caption(_ tab: MapTab) -> String {
        let pins = tab.pins.isEmpty ? nil : "ピン \(tab.pins.count)個"
        return [Self.results(tab), pins].compactMap(\.self).joined(separator: "・")
    }

    /// What the tab's search found, in the same words on its results page and on a pin page over them. Nil for a
    /// tab that has pins and no search.
    static func results(_ tab: MapTab) -> String? {
        switch tab.current.page.searchState {
        case nil: tab.pins.isEmpty ? "未検索" : nil
        case .idle, .searching: "検索中…"
        case .throttled: "再検索を待っています"
        case .failed: "検索できませんでした"
        case .loaded(let places): "\(places.count)件"
        }
    }
}

/// The pin the overview has selected: for every other tab its nearest spot with the straight-line distance, and
/// a button that opens the pin in its own tab.
struct OverviewPinPage: View {
    let tab: MapTab
    let pin: Pin
    let nearest: [NearestEntry]
    let onJump: (NearestEntry) -> Void
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    SpotSymbol(systemName: "mappin", color: tab.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pin.name)
                            .font(.title3.weight(.semibold))
                            .accessibilityIdentifier("overviewPinTitle")
                        Text(tab.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("選択を解除")
                    .accessibilityIdentifier("overviewPinCloseButton")
                }
            }
            NearestSection(entries: nearest, onJump: onJump)
            Section {
                Button("このピンをタブで開く", systemImage: "arrow.up.right.square", action: onOpen)
                    .accessibilityIdentifier("openPinInTabButton")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

/// Lays its subviews out left to right and wraps to a new line when the width runs out.
struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = frames(for: subviews, width: proposal.width ?? .infinity)
        return CGSize(width: frames.map(\.maxX).max() ?? 0, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, frames(for: subviews, width: bounds.width)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func frames(for subviews: Subviews, width: CGFloat) -> [CGRect] {
        var frames: [CGRect] = []
        var origin = CGPoint.zero
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if origin.x > 0 && origin.x + size.width > width {
                origin = CGPoint(x: 0, y: origin.y + lineHeight + lineSpacing)
                lineHeight = 0
            }
            frames.append(CGRect(origin: origin, size: size))
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return frames
    }
}
