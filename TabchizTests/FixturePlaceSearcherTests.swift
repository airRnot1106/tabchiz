import MapKit
import Testing

@testable import Tabchiz

struct FixturePlaceSearcherTests {
    @Test func bundledSupermarketsAreTheInventedGrid() async throws {
        let places = try await FixturePlaceSearcher().search(
            SearchQuery(text: "スーパー"),
            region: CameraRegion.defaultArea.mkRegion
        )

        #expect(places.count == 25)
        #expect(places.first?.name == "テストスーパー01")
        #expect(places.allSatisfy { $0.category == .foodMarket })
    }

    @Test func everyPresetTheUITestsUseHasTwentyFivePlaces() async throws {
        let searcher = FixturePlaceSearcher()
        for text in ["スーパー", "ジム", "カフェ"] {
            let places = try await searcher.search(SearchQuery(text: text), region: CameraRegion.defaultArea.mkRegion)
            #expect(places.count == 25)
            #expect(places.dedupedByID().count == 25)
        }
    }

    /// テストジム01 is 0.0012 degrees of latitude north of テストスーパー01: 6 371 008.8 m × π / 180 × 0.0012 = 133.43 m.
    /// テストスーパー02 is 0.0007 degrees north of テストジム01: 77.84 m.
    @Test func theNearestPairsTheUITestsReadHaveHandCheckedDistances() async throws {
        let searcher = FixturePlaceSearcher()
        let region = CameraRegion.defaultArea.mkRegion
        let supermarkets = try await searcher.search(SearchQuery(text: "スーパー"), region: region)
        let gyms = try await searcher.search(SearchQuery(text: "ジム"), region: region)
        let first = try #require(supermarkets.first)

        let nearestGym = try #require(gyms.min { $0.distance(to: first) < $1.distance(to: first) })
        #expect(nearestGym.name == "テストジム01")
        #expect(abs(nearestGym.distance(to: first) - 133.43) < 1)

        let nearestSupermarket = try #require(
            supermarkets.min { $0.distance(to: nearestGym) < $1.distance(to: nearestGym) })
        #expect(nearestSupermarket.name == "テストスーパー02")
        #expect(abs(nearestSupermarket.distance(to: nearestGym) - 77.84) < 1)
    }

    @Test func queriesWithoutASnapshotFindNothing() async throws {
        let places = try await FixturePlaceSearcher().search(
            SearchQuery(text: "ラーメン"),
            region: CameraRegion.defaultArea.mkRegion
        )

        #expect(places.isEmpty)
    }
}

extension Place {
    fileprivate func distance(to other: Place) -> Double {
        coordinate.distance(to: other.coordinate)
    }
}
