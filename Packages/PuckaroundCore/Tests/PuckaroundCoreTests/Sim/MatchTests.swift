import XCTest

@testable import PuckaroundCore

/// A match is first to `gamesToWin` games; each game is first to `pointsToWin`
/// points. A single game is `gamesToWin == 1`.
final class MatchTests: XCTestCase {
    private let bottom = MalletSlot.bottomSingle
    private let top = MalletSlot.topSingle

    /// A rink in play, one game short of the given rules, mallets parked.
    private func rink(_ rules: Rules) -> Rink {
        var r = Rink(table: .duel, rules: rules, seed: 1)
        r.startPlaying()
        r.park()
        return r
    }

    /// Drives a whole game to a win for `winner` by shooting into its opponent's
    /// goal `pointsToWin` times, readying up between goals as needed.
    private func winGame(_ r: inout Rink, for winner: Side) {
        while r.lastOutcome == nil {
            if r.isFaceoff {
                for slot in r.slots { r.ready(slot) }
            }
            // Park the puck just short of the loser's goal line and let it cross.
            let against = winner.opponent
            let y = against == .top ? r.table.puckField.minY + 1 : r.table.puckField.maxY - 1
            let dir = against == .top ? -1.0 : 1.0
            r.place(Puck(position: Vec2(r.table.center.x, y), velocity: Vec2(0, dir * 300)))
            for _ in 0..<6 where r.lastOutcome == nil { r.advance(inputs: [:]) }
        }
    }

    func testASingleGameEndsTheMatch() {
        var r = rink(Rules(pointsToWin: 3, gamesToWin: 1))
        winGame(&r, for: .bottom)
        XCTAssertEqual(r.gamesWon(of: .bottom), 1)
        XCTAssertEqual(r.lastOutcome, Rink.Outcome(winner: .bottom, endedMatch: true))
        XCTAssertTrue(r.events.contains(.matchOver(winner: .bottom)))
    }

    func testAGameWinTalliesButDoesNotEndABestOfThree() {
        var r = rink(Rules(pointsToWin: 3, gamesToWin: 2))
        winGame(&r, for: .bottom)
        XCTAssertEqual(r.gamesWon(of: .bottom), 1, "one game to bottom")
        XCTAssertEqual(r.lastOutcome, Rink.Outcome(winner: .bottom, endedMatch: false))
        XCTAssertTrue(r.events.contains(.gameWon(winner: .bottom)))
        let matchOver = r.events.contains {
            if case .matchOver = $0 { return true }
            return false
        }
        XCTAssertFalse(matchOver, "the match isn't over on the first game")
    }

    func testReadyingUpAfterAGameStartsTheNextWithScoreResetAndTallyKept() {
        var r = rink(Rules(pointsToWin: 3, gamesToWin: 2))
        winGame(&r, for: .bottom)
        XCTAssertGreaterThan(r.score(of: .bottom), 0, "the game score is still up")
        for slot in r.slots { r.ready(slot) }
        XCTAssertEqual(r.phase, .playing, "the next game began")
        XCTAssertEqual(r.score, [0, 0], "points reset for the new game")
        XCTAssertEqual(r.gamesWon(of: .bottom), 1, "but the games tally carried over")
    }

    func testTheMatchEndsWhenASideTakesEnoughGames() {
        var r = rink(Rules(pointsToWin: 3, gamesToWin: 2))
        winGame(&r, for: .bottom)  // 1–0
        for slot in r.slots { r.ready(slot) }  // start game 2
        winGame(&r, for: .bottom)  // 2–0 → match
        XCTAssertEqual(r.gamesWon(of: .bottom), 2)
        XCTAssertEqual(r.lastOutcome, Rink.Outcome(winner: .bottom, endedMatch: true))
        XCTAssertTrue(r.events.contains(.matchOver(winner: .bottom)))
    }

    func testReadyingUpAfterAMatchStartsAFreshMatch() {
        var r = rink(Rules(pointsToWin: 3, gamesToWin: 1))
        winGame(&r, for: .bottom)
        XCTAssertEqual(r.gamesWon(of: .bottom), 1)
        for slot in r.slots { r.ready(slot) }
        XCTAssertEqual(r.score, [0, 0], "points cleared")
        XCTAssertEqual(r.gamesWon, [0, 0], "and the games tally cleared for a fresh match")
    }

    func testAMatchCanBeSplitBeforeItEnds() {
        var r = rink(Rules(pointsToWin: 3, gamesToWin: 2))
        winGame(&r, for: .bottom)  // 1–0
        for slot in r.slots { r.ready(slot) }
        winGame(&r, for: .top)  // 1–1
        XCTAssertEqual(r.gamesWon, [1, 1])
        XCTAssertEqual(r.lastOutcome, Rink.Outcome(winner: .top, endedMatch: false))
    }

    func testAMatchRunIsDeterministic() {
        func run() -> Rink {
            var r = rink(Rules(pointsToWin: 2, gamesToWin: 2))
            winGame(&r, for: .bottom)
            for slot in r.slots { r.ready(slot) }
            winGame(&r, for: .top)
            return r
        }
        XCTAssertEqual(run(), run())
    }
}
