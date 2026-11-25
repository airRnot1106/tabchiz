import Testing

@testable import Tabchiz

struct PlaceTests {
    @Test func appleIdentifierIsUsedAsPlaceID() {
        let id = PlaceID(appleIdentifier: "I123", name: "店", coordinate: Coordinate(latitude: 35, longitude: 139))

        #expect(id.rawValue == "I123")
    }

    @Test func placesWithoutIdentifierWithinAboutOneMeterShareAnID() {
        let first = PlaceID(
            appleIdentifier: nil,
            name: "テスト駅弁屋",
            coordinate: Coordinate(latitude: 35.674_001_1, longitude: 139.721_998_9)
        )
        let second = PlaceID(
            appleIdentifier: "",
            name: "テスト駅弁屋",
            coordinate: Coordinate(latitude: 35.673_999_6, longitude: 139.722_001_2)
        )
        let elsewhere = PlaceID(
            appleIdentifier: nil,
            name: "テスト駅弁屋",
            coordinate: Coordinate(latitude: 35.674_1, longitude: 139.722_0)
        )

        #expect(first == second)
        #expect(first != elsewhere)
    }

    @Test func dedupingKeepsTheFirstPlaceOfEachID() {
        let original = SamplePlaces.place("I1", "A", 35.0, 139.0)
        let duplicate = SamplePlaces.place("I1", "A (別名)", 35.0, 139.0)
        let other = SamplePlaces.place("I2", "B", 35.1, 139.1)

        #expect([original, other, duplicate].dedupedByID() == [original, other])
    }

    @Test func presetNamesMapToTheirCategory() {
        #expect(SearchQuery(text: " スーパー ").category == .foodMarket)
        #expect(SearchQuery(text: "ジム").category == .fitnessCenter)
        #expect(SearchQuery(text: "カフェ").category == .cafe)
        #expect(SearchQuery(text: "コンビニ").category == .foodMarket)
        #expect(SearchQuery(text: "病院").category == nil)
        #expect(SearchQuery(text: "ラーメン").category == nil)
    }
}
