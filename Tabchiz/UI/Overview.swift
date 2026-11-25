import SwiftUI

/// Which color is which tab, over the overview map.
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
        .accessibilityLabel("凡例 " + tabs.map(\.title).joined(separator: "、"))
        .accessibilityIdentifier("overviewLegend")
    }
}

/// The tabs as a list with their result counts. Picking one leaves the overview for that tab.
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
                Text("地図の点をタップすると、そのタブでその場所を開きます。数字をタップすると、そのタブでその周辺を表示します。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func caption(_ tab: MapTab) -> String {
        switch tab.current.page {
        case .blank: "未検索"
        case .results(_, .idle), .results(_, .searching): "検索中…"
        case .results(_, .throttled): "再検索を待っています"
        case .results(_, .failed): "検索できませんでした"
        case .results(_, .loaded(let places)): "\(places.count)件"
        case .place(let shown): "\(shown.places.count)件"
        }
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
