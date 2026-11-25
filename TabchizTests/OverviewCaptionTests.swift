import Foundation
import Testing

@testable import Tabchiz

@MainActor
struct OverviewCaptionTests {
    typealias Samples = SamplePlaces

    let west = Coordinate(latitude: 35.6749, longitude: 139.7164)

    /// A browser whose only tab holds one pin and shows that pin's page over a ジム search in `state`.
    private func pinPage(over state: SearchState) throws -> MapTab {
        var browser = Browser()
        let id = browser.activeTab.id
        let pin = try browser.droppedPin(at: west, in: id)
        browser.submit(LoadedBrowser.gym, in: id)
        let search = try #require(browser.tab(id)?.current.page.search)
        browser.applySearch(state, for: search, in: id)
        browser.openPin(PinRef(tabID: id, pinID: pin.id))
        return try #require(browser.tab(id))
    }

    @Test(arguments: [
        (SearchState.idle, "検索中…"),
        (.searching, "検索中…"),
        (.throttled(retryAt: Date(timeIntervalSince1970: 0)), "再検索を待っています"),
        (.failed(message: "テスト用の失敗"), "検索できませんでした"),
    ])
    func aPinPageOverASearchShowsTheStateOfThatSearch(state: SearchState, caption: String) throws {
        let tab = try pinPage(over: state)

        #expect(OverviewPage.results(tab) == caption)
    }

    @Test func aPinPageOverLoadedResultsShowsTheirCount() throws {
        let tab = try pinPage(over: .loaded(Samples.gyms))

        #expect(OverviewPage.results(tab) == "\(Samples.gyms.count)件")
    }

    @Test func aPinPageOverABlankPageShowsNoResults() throws {
        var browser = Browser()
        let id = browser.activeTab.id
        let pin = try browser.droppedPin(at: west, in: id)
        browser.openPin(PinRef(tabID: id, pinID: pin.id))

        #expect(OverviewPage.results(try #require(browser.tab(id))) == nil)
    }
}
