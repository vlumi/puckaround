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

    func testFirstToTheLimitWinsAndTheGameFreezes() {
        var r = rink(rules: Rules(pointsToWin: 2))
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertEqual(r.phase, .playing)
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertEqual(r.phase, .finished(winner: top))
        XCTAssertEqual(r.puck.position, r.table.center)
        let frozen = r
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(5, 5))])
        XCTAssertEqual(r.mallets, frozen.mallets, "nothing moves after the final goal")
        XCTAssertEqual(r.tick, frozen.tick + 1, "but the clock still counts")
    }

    func testNewGameResetsEverythingButTheSeed() {
        var r = rink(rules: Rules(pointsToWin: 1))
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertEqual(r.phase, .finished(winner: top))
        r.newGame()
        XCTAssertEqual(r.score, [0, 0])
        XCTAssertEqual(r.phase, .playing)
        XCTAssertFalse(r.puck.isMoving)
        for player in r.lineup.players {
            XCTAssertEqual(
                r.mallet(of: player).position,
                r.table.malletZone(for: r.lineup.seat(of: player)).center)
        }
    }

    func testOpeningPossessionComesFromTheSeed() {
        var seen = Set<Double>()
        for seed in 0..<20 {
            seen.insert(Rink(table: .duel, lineup: .duel, seed: UInt64(seed)).puck.position.y)
        }
        XCTAssertEqual(seen.count, 2, "both halves get the opening puck across seeds")
    }
}
