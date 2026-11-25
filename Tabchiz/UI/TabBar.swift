import SwiftUI

/// The tabs at the bottom of the sheet: a color dot and a name each, one tap to switch. The strip scrolls when the
/// tabs do not fit, and the overview item stays in place next to it.
struct TabBar: View {
    static let height: CGFloat = 60

    let store: BrowserStore

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(store.browser.tabs.enumerated()), id: \.element.id) { index, tab in
                            tabItem(tab, index: index)
                                .id(tab.id)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 8)
                }
                .scrollIndicators(.hidden)
                // The bar leaves the screen while a query is typed, and comes back on the tab on screen.
                .onAppear { proxy.scrollTo(store.browser.mode.tabID) }
                .onChange(of: store.browser.mode.tabID) { _, id in
                    withAnimation { proxy.scrollTo(id) }
                }
            }
            Divider()
                .frame(height: 28)
            overviewItem
                .padding(.leading, 8)
                .padding(.trailing, 16)
        }
        .frame(height: Self.height)
        // The bar keeps its height, like a system tab bar.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func tabItem(_ tab: MapTab, index: Int) -> some View {
        let isOnScreen = store.browser.mode == .tab(tab.id)
        return Button {
            store.showTab(tab.id)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(tab.color.color)
                    .frame(width: 10, height: 10)
                Text(tab.title)
                    .font(.subheadline.weight(isOnScreen ? .semibold : .regular))
                    .lineLimit(1)
                    .frame(maxWidth: 140)
                    .fixedSize()
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                isOnScreen ? AnyShapeStyle(tab.color.color.opacity(0.25)) : AnyShapeStyle(.fill.tertiary), in: Capsule()
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isOnScreen ? .isSelected : [])
        .accessibilityIdentifier("tab.\(index)")
        .contextMenu {
            Button("タブを閉じる", systemImage: "xmark", role: .destructive) {
                store.removeTab(tab.id)
            }
            .accessibilityIdentifier("closeTabAction")
        }
    }

    /// One tap enters the overview. Another tap, or a tap on a tab, leaves it.
    private var overviewItem: some View {
        let isOnScreen = store.browser.mode.scene == .overview
        return Button {
            store.toggleOverview()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.3.layers.3d")
                    .font(.footnote)
                Text("全体")
                    .font(.subheadline.weight(isOnScreen ? .semibold : .regular))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(isOnScreen ? AnyShapeStyle(.fill) : AnyShapeStyle(.fill.tertiary), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("全体")
        .accessibilityAddTraits(isOnScreen ? .isSelected : [])
        .accessibilityIdentifier("overviewTab")
    }
}
