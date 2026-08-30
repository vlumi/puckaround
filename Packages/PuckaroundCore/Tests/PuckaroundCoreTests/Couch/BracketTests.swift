import XCTest

@testable import PuckaroundCore

/// A knockout sheet: random but seeded draw, byes for uneven counts, losers
/// out, one champion.
final class BracketTests: XCTestCase {
    private let four = ["Anna", "Ville", "Mei", "Juho"]

    func testAFullFieldDrawsWithNoByes() {
        let b = Bracket(roster: four, seed: 7)!
        XCTAssertEqual(b.rounds.map(\.count), [4, 2, 1])
        XCTAssertEqual(b.rounds[0].compactMap { $0 }.sorted(), four.sorted(), "everyone seated")
        XCTAssertNil(b.champion)
        XCTAssertNotNil(b.current)
    }

    func testTooFewOrTooManyIsNoBracket() {
        XCTAssertNil(Bracket(roster: [], seed: 1))
        XCTAssertNil(Bracket(roster: ["Anna"], seed: 1))
        XCTAssertNil(Bracket(roster: ["Anna", "Anna"], seed: 1))
        XCTAssertNil(Bracket(roster: (0...32).map(String.init), seed: 1), "33 is past the cap")
        XCTAssertNotNil(Bracket(roster: (1...32).map(String.init), seed: 1))
    }

    /// Three players on a four-slot sheet: one random bye advances unplayed,
    /// and the whole bracket takes exactly two matches.
    func testAnUnevenFieldGetsAByeAndStillCrownsAChampion() {
        var b = Bracket(roster: ["Anna", "Ville", "Mei"], seed: 3)!
        XCTAssertEqual(b.rounds[0].compactMap { $0 }.count, 3)
        XCTAssertEqual(b.rounds[1].compactMap { $0 }.count, 1, "the bye advanced unplayed")
        var matches = 0
        while b.current != nil {
            b.recordWin(by: .bottom)
            matches += 1
        }
        XCTAssertEqual(matches, 2)
        XCTAssertNotNil(b.champion)
    }

    /// Byes never meet: every round-one match has at least one real player.
    func testByesNeverPairWithEachOther() {
        for count in 2...32 {
            let names = (1...count).map { "P\($0)" }
            let b = Bracket(roster: names, seed: UInt64(count))!
            let first = b.rounds[0]
            for match in 0..<(first.count / 2) {
                XCTAssertFalse(
                    first[2 * match] == nil && first[2 * match + 1] == nil,
                    "\(count) players: match \(match) is empty")
            }
        }
    }

    func testTheWinnerAdvancesAndTheResultIsRemembered() {
        var b = Bracket(roster: four, seed: 7)!
        let pairing = b.current!
        b.recordWin(by: .top, winnerScore: 7, loserScore: 4)
        XCTAssertEqual(b.rounds[1].compactMap { $0 }, [pairing.top])
        XCTAssertEqual(
            b.lastMatch,
            MatchResult(
                winner: pairing.top, loser: pairing.bottom, winnerScore: 7, loserScore: 4))
    }

    func testAFourPlayerBracketPlaysThreeMatchesToAChampion() {
        var b = Bracket(roster: four, seed: 9)!
        var matches = 0
        while let pairing = b.current {
            b.recordWin(by: .bottom)
            matches += 1
            XCTAssertFalse(pairing.bottom == pairing.top)
        }
        XCTAssertEqual(matches, 3)
        XCTAssertNotNil(b.champion)
        XCTAssertNil(b.current, "nothing left to play")
    }

    /// The same seed draws the same sheet — the draw is deterministic.
    func testTheDrawIsDeterministic() {
        XCTAssertEqual(Bracket(roster: four, seed: 42), Bracket(roster: four, seed: 42))
    }

    /// The sheet must survive the app quitting mid-evening.
    func testCodableRoundTrip() throws {
        var b = Bracket(roster: four, seed: 5)!
        b.recordWin(by: .bottom, winnerScore: 7, loserScore: 2)
        let data = try JSONEncoder().encode(b)
        let back = try JSONDecoder().decode(Bracket.self, from: data)
        XCTAssertEqual(back, b)
    }
}
