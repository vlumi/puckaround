import XCTest

@testable import PuckaroundCore

/// The one handle the flow drives, routing to whichever shape is underneath.
final class EveningTests: XCTestCase {
    func testWinnerStaysRoutesThroughTheHandle() {
        var e = Evening.winnerStays(Tournament(roster: ["Anna", "Ville", "Mei"])!)
        XCTAssertEqual(e.pairing, Pairing(bottom: "Anna", top: "Ville"))
        XCTAssertNil(e.champion, "winner stays never crowns anyone")
        e.recordWin(by: .bottom, winnerScore: 7, loserScore: 5)
        XCTAssertEqual(e.pairing, Pairing(bottom: "Anna", top: "Mei"))
        XCTAssertEqual(e.lastMatch?.winner, "Anna")
    }

    func testABracketRoutesToItsChampion() {
        var e = Evening.bracket(Bracket(roster: ["Anna", "Ville"], seed: 1)!)
        XCTAssertNotNil(e.pairing)
        e.recordWin(by: .top, winnerScore: 7, loserScore: 0)
        XCTAssertNil(e.pairing, "the final is played")
        XCTAssertNotNil(e.champion)
        XCTAssertEqual(e.champion, e.lastMatch?.winner)
    }

    /// The evening survives the app quitting, whichever shape it is.
    func testCodableRoundTripForBothShapes() throws {
        let evenings: [Evening] = [
            .winnerStays(Tournament(roster: ["Anna", "Ville", "Mei"])!),
            .bracket(Bracket(roster: ["Anna", "Ville", "Mei"], seed: 2)!),
        ]
        for e in evenings {
            let data = try JSONEncoder().encode(e)
            XCTAssertEqual(try JSONDecoder().decode(Evening.self, from: data), e)
        }
    }
}
