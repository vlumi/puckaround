import XCTest

@testable import PuckaroundCore

/// Goals, serves, and the end of a game.
final class ScoringTests: XCTestCase {
    private let bottom = PlayerID(0)
    private let top = PlayerID(1)

    private func rink(rules: Rules = .standard) -> Rink {
        var r = Rink(table: .duel, lineup: .duel, rules: rules, seed: 1)
        r.park()
        return r
    }

    /// Fires the puck at a short wall at `x`, from just inside it, and steps once.
    private func shoot(_ r: inout Rink, at edge: Seat, x: Double) {
        let y = edge == .top ? r.table.puckField.minY + 1 : r.table.puckField.maxY - 1
        r.place(Puck(position: Vec2(x, y), velocity: Vec2(0, edge == .top ? -300 : 300)))
        r.advance(inputs: [:])
    }

    func testAGameOpensWithThePuckAtRestInOneHalf() {
        let r = Rink(table: .duel, lineup: .duel, seed: 1)
        XCTAssertEqual(r.score, [0, 0])
        XCTAssertEqual(r.phase, .playing)
        XCTAssertFalse(r.puck.isMoving)
        XCTAssertNotEqual(r.puck.position.y, r.table.center.y, "somebody has possession")
    }

    func testAServedPuckIsClearOfTheMalletAtHome() {
        let r = Rink(table: .duel, lineup: .duel, seed: 1)
        let reach = r.table.puckRadius + r.table.malletRadius
        for player in r.lineup.players {
            let spot = r.table.serveSpot(for: r.lineup.seat(of: player))
            let home = r.table.malletZone(for: r.lineup.seat(of: player)).center
            XCTAssertGreaterThan(
                spot.distance(to: home), reach, "a serve must not spawn inside the mallet")
            XCTAssertNotEqual(spot.y, r.table.center.y)
        }
    }

    func testThePuckThroughTheTopGoalScoresForTheBottomSeat() {
        var r = rink()
        shoot(&r, at: .top, x: r.table.center.x)
        XCTAssertEqual(r.score(of: bottom), 1)
        XCTAssertEqual(r.score(of: top), 0)
    }

    func testTheConcederGetsThePuck() {
        var r = rink()
        shoot(&r, at: .top, x: r.table.center.x)
        XCTAssertEqual(r.puck.position, r.table.serveSpot(for: .top))
        XCTAssertFalse(r.puck.isMoving)
        XCTAssertLessThan(r.puck.position.y, r.table.center.y, "in the top half")
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertEqual(r.score, [1, 1])
        XCTAssertEqual(r.puck.position, r.table.serveSpot(for: .bottom))
    }

    func testThePostsAreWall() {
        var r = rink()
        let postX = r.table.center.x + r.table.goalWidth / 2  // dead on the post
        shoot(&r, at: .top, x: postX)
        XCTAssertEqual(r.score, [0, 0])
        XCTAssertGreaterThan(r.puck.velocity.y, 0, "bounced back")
        // Just inside the mouth, but not clear of the post by a puck radius: still a post.
        var r2 = rink()
        shoot(&r2, at: .top, x: postX - r.table.puckRadius + 0.5)
        XCTAssertEqual(r2.score, [0, 0])
        // Clear of the post by a full radius: a goal.
        var r3 = rink()
        shoot(&r3, at: .top, x: postX - r.table.puckRadius)
        XCTAssertEqual(r3.score, [1, 0])
    }

    func testFirstToTheLimitWinsAndFreezesThePuckOnly() {
        var r = rink(rules: Rules(pointsToWin: 2))
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertEqual(r.phase, .playing)
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertEqual(r.phase, .finished(winner: top))
        XCTAssertEqual(r.puck.position, r.table.center)
        let finished = r
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(5, -5))])
        XCTAssertEqual(
            r.mallet(of: bottom).position, finished.mallet(of: bottom).position + Vec2(5, -5),
            "hands stay live")
        XCTAssertEqual(r.puck, finished.puck, "the puck is done")
        XCTAssertEqual(r.tick, finished.tick + 1)
    }

    func testAFinishedGamesMalletCannotDisturbTheParkedPuck() {
        var r = rink(rules: Rules(pointsToWin: 1))
        shoot(&r, at: .bottom, x: r.table.center.x)
        // Drive the bottom mallet up onto the centre line, right under the puck.
        r.placeMallet(of: bottom, at: Vec2(r.table.center.x, r.table.center.y + 30))
        for _ in 0..<10 {
            r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, -5))])
        }
        XCTAssertEqual(r.mallet(of: bottom).position.y, r.table.center.y + r.table.malletRadius)
        XCTAssertEqual(r.puck.position, r.table.center)
        XCTAssertFalse(r.puck.isMoving)
    }

    func testNewGameResetsTheScoreAndPuckButLeavesTheMallets() {
        var r = rink(rules: Rules(pointsToWin: 1))
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertEqual(r.phase, .finished(winner: top))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(3, -3))])
        let hands = r.mallets
        r.newGame()
        XCTAssertEqual(r.score, [0, 0])
        XCTAssertEqual(r.phase, .playing)
        XCTAssertFalse(r.puck.isMoving)
        XCTAssertEqual(r.mallets, hands, "the mallets are where the hands left them")
    }

    func testOpeningPossessionComesFromTheSeed() {
        var seen = Set<Double>()
        for seed in 0..<20 {
            seen.insert(Rink(table: .duel, lineup: .duel, seed: UInt64(seed)).puck.position.y)
        }
        XCTAssertEqual(seen.count, 2, "both halves get the opening puck across seeds")
    }
}
