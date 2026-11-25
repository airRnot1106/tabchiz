import Foundation
import Testing

@testable import Tabchiz

struct NearestTests {
    typealias Samples = SamplePlaces

    @Test func nearestGymToSeijoIshiiIsJumpOneEast2About133Meters() throws {
        let nearest = try #require(
            nearestSpot(to: Samples.market.coordinate, in: Samples.gyms.map(Spot.place)))

        #expect(nearest.spot == .place(Samples.nearGym))
        #expect(abs(nearest.distance - 133.43) < 1)
        #expect(abs(nearest.distance - Samples.haversine(Samples.market, Samples.nearGym)) < 1)
    }

    @Test func distanceToSecondNearestGymMatchesHaversine() {
        let distance = Samples.market.coordinate.distance(to: Samples.nextGym.coordinate)

        #expect(abs(distance - 200.15) < 1)
        #expect(abs(distance - Samples.haversine(Samples.market, Samples.nextGym)) < 1)
    }

    @Test func noCandidatesGivesNoNearestPlace() {
        #expect(nearestSpot(to: Samples.market.coordinate, in: []) == nil)
    }

    @Test func distancesBelowOneKilometerAreShownInWholeMeters() {
        #expect(DistanceText.straightLine(133.43) == "直線 133 m")
        #expect(DistanceText.short(999.4) == "999 m")
        #expect(DistanceText.short(1_249) == "1.2 km")
    }

    // MARK: Pins

    /// A tab that holds one pin for every place of `pins` and has loaded `places` as the results of `query`.
    private func tab(pinsAt pins: [Place] = [], query: SearchQuery? = nil, places: [Place] = []) -> MapTab {
        var tab = MapTab(color: .orange, query: query, camera: .defaultArea)
        for pin in pins {
            tab.dropPin(at: pin.coordinate)
        }
        if let search = tab.current.page.search {
            tab.apply(.loaded(places), for: search)
        }
        return tab
    }

    @Test func aPinsNearestSpotInATabOfResultsIsTheNearestResult() throws {
        let apartments = tab(pinsAt: [Samples.market])
        let gyms = tab(query: LoadedBrowser.gym, places: Samples.gyms)

        let matches = nearestMatches(
            from: Samples.market.coordinate, excluding: apartments.id, in: [apartments, gyms])

        #expect(matches.map(\.tabID) == [gyms.id])
        #expect(matches.first?.spot == .place(Samples.nearGym))
        #expect(abs((matches.first?.distance ?? 0) - 133.43) < 1)
    }

    @Test func aPlacesNearestSpotInATabOfPinsIsTheNearestPin() throws {
        let supermarkets = tab(query: LoadedBrowser.supermarket, places: [Samples.market])
        let apartments = tab(pinsAt: [Samples.nextGym, Samples.nearGym, Samples.farGym])

        let matches = nearestMatches(
            from: Samples.market.coordinate, excluding: supermarkets.id, in: [supermarkets, apartments])

        #expect(matches.map(\.tabID) == [apartments.id])
        #expect(matches.first?.spot == .pin(apartments.pins[1]))
        #expect(abs((matches.first?.distance ?? 0) - 133.43) < 1)
    }

    @Test func aTabsPinsAndResultsAreComparedTogether() throws {
        let origin = Samples.market.coordinate
        let viewed = tab()
        // The pin at 133 m is nearer than both results.
        let pinWins = tab(
            pinsAt: [Samples.nearGym], query: LoadedBrowser.gym,
            places: [Samples.farGym, Samples.nextGym])
        // The result at 133 m is nearer than the pin at 198 m.
        let resultWins = tab(
            pinsAt: [Samples.nextGym], query: LoadedBrowser.gym,
            places: [Samples.farGym, Samples.nearGym])

        let matches = nearestMatches(from: origin, excluding: viewed.id, in: [viewed, pinWins, resultWins])

        #expect(matches.map(\.tabID) == [pinWins.id, resultWins.id])
        #expect(matches.map(\.spot) == [.pin(pinWins.pins[0]), .place(Samples.nearGym)])
        #expect(matches.allSatisfy { abs($0.distance - 133.43) < 1 })
    }

    @Test func aPinnedResultCountsAsThePin() throws {
        let viewed = tab()
        var gyms = tab(query: LoadedBrowser.gym, places: Samples.gyms)
        let pinned = gyms.pinPlace(Samples.nearGym.id)
        let pin = try #require(pinned)

        let matches = nearestMatches(
            from: Samples.market.coordinate, excluding: viewed.id, in: [viewed, gyms])

        #expect(matches.map(\.spot) == [.pin(pin)])
    }

    @Test func tabsWithoutPinsAndResultsAndTheViewedTabAreLeftOut() {
        let viewed = tab(pinsAt: [Samples.market, Samples.southGym])
        let blank = tab()
        let empty = tab(query: LoadedBrowser.gym, places: [])

        let matches = nearestMatches(
            from: Samples.market.coordinate, excluding: viewed.id, in: [viewed, blank, empty])

        #expect(matches.isEmpty)
    }
}
