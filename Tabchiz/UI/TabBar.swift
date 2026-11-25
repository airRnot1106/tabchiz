import SwiftUI

/// The tabs at the bottom of the sheet: a color dot and a name each, one tap to switch. The strip scrolls when the
/// tabs do not fit.
struct TabBar: View {
    static let height: CGFloat = 60

    let store: BrowserStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(store.browser.tabs.enumerated()), id: \.element.id) { index, tab in
                        tabItem(tab, index: index)
                            .id(tab.id)
                    }
                    newTabButton
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .onChange(of: store.browser.mode.tabID) { _, id in
                withAnimation { proxy.scrollTo(id) }
            }
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
}
