/// The Okabe-Ito palette without black, yellow and blue, so every tab stays distinguishable for colorblind users
/// and against the map's own blue water and yellow roads.
nonisolated enum TabColor: String, CaseIterable, Codable, Sendable {
    case orange
    case skyBlue
    case bluishGreen
    case vermillion
    case reddishPurple

    /// The first color in palette order that no tab uses, or nil when all five are taken.
    static func firstFree(excluding used: some Sequence<Self>) -> Self? {
        let usedSet = Set(used)
        return allCases.first { !usedSet.contains($0) }
    }
}
