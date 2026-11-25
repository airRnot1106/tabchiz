import MapKit

nonisolated struct SearchQuery: Hashable, Sendable {
    let text: String
    let category: MKPointOfInterestCategory?

    init(text: String, category: MKPointOfInterestCategory?) {
        self.text = text
        self.category = category
    }

    /// A preset name maps to its category. Any other text is searched without a category filter.
    init(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(text: trimmed, category: SearchPreset.matching(trimmed)?.category)
    }
}

nonisolated struct SearchPreset: Hashable, Sendable, Identifiable {
    let name: String
    let category: MKPointOfInterestCategory

    var id: String { name }
    var query: SearchQuery { SearchQuery(text: name, category: category) }

    /// Each mapping was checked against live Apple Maps results. コンビニ is a food market in Apple Maps:
    /// filtering it as a store finds nothing. 病院 is left out because the hospital filter drops every clinic.
    static let all: [Self] = [
        Self(name: "スーパー", category: .foodMarket),
        Self(name: "ジム", category: .fitnessCenter),
        Self(name: "カフェ", category: .cafe),
        Self(name: "コンビニ", category: .foodMarket),
        Self(name: "駅", category: .publicTransport),
        Self(name: "薬局", category: .pharmacy),
        Self(name: "公園", category: .park),
        Self(name: "本屋", category: .store),
        Self(name: "レストラン", category: .restaurant),
    ]

    static func matching(_ text: String) -> Self? {
        all.first { $0.name == text }
    }
}
