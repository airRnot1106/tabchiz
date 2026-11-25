import SwiftUI
import UIKit

extension TabColor {
    /// System colors, which adapt to Dark Mode and Increase Contrast. Blue is left out because the map draws water,
    /// transit and the user's location in blue.
    var uiColor: UIColor {
        switch self {
        case .orange: .systemOrange
        case .skyBlue: .systemCyan
        case .bluishGreen: .systemGreen
        case .vermillion: .systemPink
        case .reddishPurple: .systemPurple
        }
    }

    var color: Color { Color(uiColor: uiColor) }
}

extension SearchQuery {
    /// SF Symbol for a preset name. Free text gets a plain pin.
    var symbolName: String {
        switch text {
        case "スーパー": "cart.fill"
        case "ジム": "dumbbell.fill"
        case "カフェ": "cup.and.saucer.fill"
        case "コンビニ": "storefront.fill"
        case "駅": "tram.fill"
        case "薬局": "cross.case.fill"
        case "公園": "tree.fill"
        case "本屋": "book.fill"
        case "レストラン": "fork.knife"
        default: "mappin"
        }
    }
}

extension MapTab {
    /// The tab's name: its query, or a placeholder while it is blank.
    var title: String { query?.text ?? "新規タブ" }

    var symbolName: String { query?.symbolName ?? "magnifyingglass" }
}

/// The tab's symbol on a circle of the tab's color, the same mark the tab's markers carry on the map.
struct TabSymbol: View {
    let tab: MapTab
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 30

    var body: some View {
        Image(systemName: tab.symbolName)
            .font(.system(size: diameter * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
            .background(tab.color.color.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}
