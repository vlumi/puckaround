import XCTest

@testable import PuckaroundCore

/// A league season: circle-method fixtures, standings by wins, ties settled
/// by head-to-head or sudden-death deciders.
final class LeagueTests: XCTestCase {
    private let four = ["Aki", "Boa", "Cai", "Dee"]

    /// The unordered pair a fixture plays, for meeting counts.
    private func pair(_ p: Pairing) -> Set<String> { [p.bottom, p.top] }

    /// Play the whole season, deciding every match by a fixed rank: the
    /// player earlier in `order` always wins.
    private func playSeason(_ league: inout League, order: [String]) {
        while league.contenders == nil, let match = league.current {
            let bottomWins =
                order.firstIndex(of: match.bottom)! < order.firstIndex(of: match.top)!
            league.recordWin(by: bottomWins ? .bottom : .top, winnerScore: 7, loserScore: 3)
        }
    }

    func testEveryoneMeetsEveryoneOnce() {
        let league = League(roster: four, doubleRound: false, seed: 5)!
        XCTAssertEqual(league.fixtures.count, 6)
        XCTAssertEqual(Set(league.fixtures.map(pair)).count, 6, "every pair distinct")
    }

    /// A double round is the season twice, the return legs end-swapped.
    func testADoubleRoundMirrorsTheReturnLegs() {
        let league = League(roster: four, doubleRound: true, seed: 5)!
        XCTAssertEqual(league.fixtures.count, 12)
        for i in 0..<6 {
            XCTAssertEqual(league.fixtures[i + 6], league.fixtures[i].mirrored)
        }
    }

    /// An odd count schedules a full round robin with nobody idle twice —
    /// the ghost seat never surfaces as a bye.
    func testAnOddCountJustSitsOneOutEachRound() {
        let league = League(
            roster: ["Aki", "Boa", "Cai", "Dee", "Eve"], doubleRound: false, seed: 5)!
        XCTAssertEqual(league.fixtures.count, 10)
        XCTAssertEqual(Set(league.fixtures.map(pair)).count, 10)
    }

    func testASoleLeaderIsChampion() {
        var league = League(roster: four, doubleRound: false, seed: 5)!
        playSeason(&league, order: four)
        XCTAssertEqual(league.champion, "Aki")
        XCTAssertNil(league.contenders)
        XCTAssertNil(league.current, "the season is over")
        XCTAssertEqual(league.standings.map(\.wins), [3, 2, 1, 0])
    }

    /// Two tied at the top, and one beat the other in the season: that
    /// head-to-head is the title, no extra match.
    func testATwoWayTieFallsToHeadToHead() {
        var league = League(roster: four, doubleRound: false, seed: 5)!
        // Aki and Boa finish 2-1 (Aki beat Boa; each dropped one elsewhere),
        // ahead of the rest — a two-way tie the head-to-head settles.
        let beats: Set<[String]> = [
            ["Aki", "Boa"], ["Aki", "Cai"], ["Dee", "Aki"],
            ["Boa", "Cai"], ["Boa", "Dee"], ["Cai", "Dee"],
        ]
        while let match = league.current, league.contenders == nil {
            league.recordWin(by: beats.contains([match.bottom, match.top]) ? .bottom : .top)
        }
        XCTAssertNil(league.contenders, "no decider needed")
        XCTAssertEqual(league.champion, "Aki", "the head-to-head settles it")
    }

    /// The same two split their double-round meetings: one decider match.
    func testASplitTieBooksOneDecider() {
        var league = League(roster: ["Aki", "Boa"], doubleRound: true, seed: 5)!
        let first = league.current!
        league.recordWin(by: .bottom)
        let second = league.current!
        league.recordWin(by: .bottom)
        XCTAssertNotEqual(first.bottom, second.bottom, "the return leg swapped ends")
        XCTAssertNil(league.champion, "split — the season alone decides nothing")
        XCTAssertEqual(Set(league.contenders ?? []), ["Aki", "Boa"])
        league.recordWin(by: .top)
        XCTAssertEqual(league.champion, league.lastMatch?.winner)
    }

    /// Three tied at the top go to sudden death: two deciders, one champion.
    func testAThreeWayTieRunsSuddenDeath() {
        var league = League(roster: ["Aki", "Boa", "Cai"], doubleRound: false, seed: 5)!
        // A beats B, B beats C, C beats A — everyone 1-1.
        let beats = [["Aki", "Boa"], ["Boa", "Cai"], ["Cai", "Aki"]]
        while let match = league.current, league.contenders == nil {
            let bottomWins = beats.contains([match.bottom, match.top])
            league.recordWin(by: bottomWins ? .bottom : .top)
        }
        XCTAssertEqual(Set(league.contenders ?? []), ["Aki", "Boa", "Cai"])
        // First decider: front two play, the winner rejoins behind the third.
        let first = league.current!
        league.recordWin(by: .bottom)
        XCTAssertNil(league.champion, "one contender still waits")
        XCTAssertFalse(league.contenders?.contains(first.top) ?? true, "the loser is out")
        league.recordWin(by: .bottom)
        XCTAssertNotNil(league.champion)
        XCTAssertNil(league.current)
    }

    func testTheDrawIsDeterministic() {
        let a = League(roster: four, doubleRound: true, seed: 9)!
        let b = League(roster: four, doubleRound: true, seed: 9)!
        XCTAssertEqual(a, b)
    }

    func testRosterLimitsAndDuplicates() {
        XCTAssertNil(League(roster: ["Aki"], doubleRound: false, seed: 1))
        XCTAssertNil(
            League(
                roster: (0...League.maxPlayers).map(String.init), doubleRound: false, seed: 1))
        let league = League(roster: ["Aki", "Aki", "Boa"], doubleRound: false, seed: 1)!
        XCTAssertEqual(league.fixtures.count, 1, "duplicates collapse")
    }

    /// The evening handle drives a league like any other shape.
    func testAnEveningCarriesALeague() {
        var evening = Evening.league(League(roster: ["Aki", "Boa"], doubleRound: false, seed: 1)!)
        XCTAssertEqual(evening.shape, .league)
        XCTAssertNil(evening.champion)
        let pairing = evening.pairing!
        evening.recordWin(by: .bottom, winnerScore: 7, loserScore: 0)
        XCTAssertEqual(evening.champion, pairing.bottom)
        XCTAssertEqual(evening.lastMatch?.loser, pairing.top)
    }
}
