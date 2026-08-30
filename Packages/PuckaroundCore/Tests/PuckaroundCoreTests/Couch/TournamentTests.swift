import XCTest

@testable import PuckaroundCore

/// Winner stays: two on the table, a line behind them, the loser to the back.
final class TournamentTests: XCTestCase {
    private let four = ["Anna", "Ville", "Mei", "Juho"]

    func testFirstTwoTakeTheTableAndTheRestLineUp() {
        let t = Tournament(roster: four)!
        XCTAssertEqual(t.bottom, "Anna")
        XCTAssertEqual(t.top, "Ville")
        XCTAssertEqual(t.line, ["Mei", "Juho"])
        XCTAssertEqual(t.upNext, "Mei")
        XCTAssertEqual(t.wins.values.reduce(0, +), 0, "nobody has won yet")
    }

    func testFewerThanTwoDistinctNamesIsNoTournament() {
        XCTAssertNil(Tournament(roster: []))
        XCTAssertNil(Tournament(roster: ["Anna"]))
        XCTAssertNil(Tournament(roster: ["Anna", "Anna"]))
    }

    /// A name is the only identity there is, so a doubled entry is one player.
    func testDuplicateNamesCollapseToTheirFirstEntry() {
        let t = Tournament(roster: ["Anna", "Ville", "Anna", "Mei"])!
        XCTAssertEqual(t.line, ["Mei"])
        XCTAssertEqual(t.players.count, 3)
    }

    func testTheWinnerStaysAndTheLoserJoinsTheBack() {
        var t = Tournament(roster: four)!
        t.recordWin(by: .bottom)
        XCTAssertEqual(t.bottom, "Anna", "the winner keeps her end")
        XCTAssertEqual(t.top, "Mei", "the challenger takes the vacated end")
        XCTAssertEqual(t.line, ["Juho", "Ville"], "the loser rejoins at the back")
        XCTAssertEqual(t.wins["Anna"], 1)
    }

    func testTheChallengerTakesWhicheverEndWasLost() {
        var t = Tournament(roster: four)!
        t.recordWin(by: .top)
        XCTAssertEqual(t.top, "Ville", "the winner keeps his end")
        XCTAssertEqual(t.bottom, "Mei")
        XCTAssertEqual(t.line, ["Juho", "Anna"])
    }

    /// With two players the line is empty and the same pair just goes again.
    func testTwoPlayersJustGoAgain() {
        var t = Tournament(roster: ["Anna", "Ville"])!
        XCTAssertNil(t.upNext)
        t.recordWin(by: .top)
        XCTAssertEqual(t.bottom, "Anna")
        XCTAssertEqual(t.top, "Ville")
        XCTAssertEqual(t.wins["Ville"], 1)
    }

    /// Three players: the loser always sits out exactly one match.
    func testThreePlayersRotateFairly() {
        var t = Tournament(roster: ["Anna", "Ville", "Mei"])!
        t.recordWin(by: .bottom)  // Ville out, Mei in
        XCTAssertEqual(t.line, ["Ville"])
        t.recordWin(by: .top)  // Mei beats Anna; Anna out, Ville back in
        XCTAssertEqual(t.bottom, "Ville")
        XCTAssertEqual(t.top, "Mei")
        XCTAssertEqual(t.line, ["Anna"])
    }

    func testStandingsSortByWinsThenName() {
        var t = Tournament(roster: four)!
        t.recordWin(by: .bottom)  // Anna 1
        t.recordWin(by: .bottom)  // Anna 2
        t.recordWin(by: .top)  // the challenger beats Anna
        let names = t.standings.map(\.name)
        XCTAssertEqual(names.first, "Anna", "most wins first")
        XCTAssertEqual(t.standings[0].wins, 2)
        // The three on zero or one win tie-break by name, stably.
        XCTAssertEqual(names, ["Anna", "Juho", "Mei", "Ville"])
    }

    /// The hold on the table: consecutive wins run the streak up, losing it
    /// hands the count back to one for the new winner.
    func testAStreakGrowsWhileTheTableIsHeld() {
        var t = Tournament(roster: four)!
        t.recordWin(by: .bottom)
        t.recordWin(by: .bottom)
        XCTAssertEqual(t.streakName, "Anna")
        XCTAssertEqual(t.streak, 2)
        t.recordWin(by: .top)  // the challenger takes the table
        XCTAssertEqual(t.streak, 1, "a new hold starts at one")
        XCTAssertNotEqual(t.streakName, "Anna")
    }

    /// The longest run of the night stays with the first player to set it.
    func testTheBestStreakIsKeptByItsFirstSetter() {
        var t = Tournament(roster: four)!
        t.recordWin(by: .bottom)
        t.recordWin(by: .bottom)  // Anna sets 2
        t.recordWin(by: .top)
        t.recordWin(by: .bottom)  // a new holder reaches 2 — ties, doesn't take
        XCTAssertEqual(t.bestStreak, 2)
        XCTAssertEqual(t.bestStreakName, "Anna")
    }

    /// The tournament must survive the app quitting mid-evening.
    func testCodableRoundTrip() throws {
        var t = Tournament(roster: four)!
        t.recordWin(by: .bottom)
        let data = try JSONEncoder().encode(t)
        let back = try JSONDecoder().decode(Tournament.self, from: data)
        XCTAssertEqual(back, t)
    }
}
