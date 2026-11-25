import Foundation
import Testing

@testable import Tabchiz

struct NearestTests {
    typealias Samples = SamplePlaces

    @Test func nearestGymToSeijoIshiiIsJumpOneEast2About133Meters() throws {
        let nearest = try #require(nearestPlace(to: Samples.market, in: Samples.gyms))

        #expect(nearest.place == Samples.nearGym)
        #expect(abs(nearest.distance - 133.43) < 1)
        #expect(abs(nearest.distance - Samples.haversine(Samples.market, Samples.nearGym)) < 1)
    }

    @Test func distanceToSecondNearestGymMatchesHaversine() {
        let distance = Samples.market.coordinate.distance(to: Samples.nextGym.coordinate)

        #expect(abs(distance - 200.15) < 1)
        #expect(abs(distance - Samples.haversine(Samples.market, Samples.nextGym)) < 1)
    }

    @Test func noCandidatesGivesNoNearestPlace() {
        #expect(nearestPlace(to: Samples.market, in: []) == nil)
    }

    @Test func distancesBelowOneKilometerAreShownInWholeMeters() {
        #expect(DistanceText.straightLine(133.43) == "直線 133 m")
        #expect(DistanceText.short(999.4) == "999 m")
        #expect(DistanceText.short(1_249) == "1.2 km")
    }
}
