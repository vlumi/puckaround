import XCTest

@testable import PuckaroundCore

/// Goals, serves, and the end of a game.
final class ScoringTests: XCTestCase {
    private let bottom = PlayerID(0)
    private let top = PlayerID(1)

    private func rink(rules: Rules = .standard) -> Rink {
        var r = Rink(table: .duel, lineup: .duel, rules: rules, seed: 1)
        r.startPlaying()
        r.park()
        return r
    }

    /// Fires the puck at a short wall at `x`, from just inside it, and steps once
    /// — which scores and serves in the same tick, so the served puck read after
    /// this has already glided one step into the conceder's half.
    private func shoot(_ r: inout Rink, at edge: Seat, x: Double) {
        let y = edge == .top ? r.table.puckField.minY + 1 : r.table.puckField.maxY - 1
        r.place(Puck(position: Vec2(x, y), velocity: Vec2(0, edge == .top ? -300 : 300)))
        r.advance(inputs: [:])
    }

    func testAGameOpensWithAFaceoffAtCentre() {
        let r = Rink(table: .duel, lineup: .duel, seed: 1)
        XCTAssertEqual(r.score, [0, 0])
        XCTAssertTrue(r.isFaceoff)
        XCTAssertEqual(r.readySeats, [])
        XCTAssertEqual(r.puck.position, r.table.center, "frozen at centre behind the field")
        XCTAssertFalse(r.puck.isMoving)
    }

    func testAServeGlidesSlowlyIntoTheCondederOwnHalf() {
        var r = rink(rules: Rules(pointsToWin: 5))
        // Bottom concedes → served toward the bottom half, gliding that way and
        // slowly (well under a struck puck's pace).
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertGreaterThan(r.puck.velocity.y, 0, "gliding down into the conceder's half")
        XCTAssertLessThan(r.puck.velocity.length, r.table.serveSpeed + 1, "a gentle serve")
        // A step later it is further into the conceder's half, and no opponent
        // (stuck on the far side of the centre line) could have reached it.
        r.advance(inputs: [:])
        XCTAssertGreaterThan(r.puck.position.y, r.table.center.y, "in the bottom half now")
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
        // Top conceded: the puck leaves centre gliding up into the top half.
        XCTAssertEqual(r.puck.position, r.table.center)
        XCTAssertLessThan(r.puck.velocity.y, 0, "heading into the top half")
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertEqual(r.score, [1, 1])
        XCTAssertGreaterThan(r.puck.velocity.y, 0, "now heading into the bottom half")
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

    func testNewGameResetsTheScoreAndOpensAFaceoffButLeavesTheMallets() {
        var r = rink(rules: Rules(pointsToWin: 1))
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertEqual(r.phase, .finished(winner: top))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(3, -3))])
        let hands = r.mallets
        r.newGame()
        XCTAssertEqual(r.score, [0, 0])
        XCTAssertTrue(r.isFaceoff, "a new game opens with a faceoff")
        XCTAssertEqual(r.puck.position, r.table.center)
        XCTAssertFalse(r.puck.isMoving)
        XCTAssertEqual(r.mallets, hands, "the mallets are where the hands left them")
    }

    func testReadyingBothSeatsStartsPlay() {
        var r = Rink(table: .duel, lineup: .duel, seed: 1)
        r.ready(bottom)
        XCTAssertTrue(r.isFaceoff, "one seat readied is not enough")
        XCTAssertEqual(r.readySeats, [bottom])
        r.ready(top)
        XCTAssertEqual(r.phase, .playing, "both readied → play begins")
    }

    func testReadyIsALatchWithNoTakeBacks() {
        var r = Rink(table: .duel, lineup: .duel, seed: 1)
        r.ready(bottom)
        r.ready(bottom)  // idempotent
        XCTAssertEqual(r.readySeats, [bottom])
        // Once playing, readying does nothing.
        r.ready(top)
        XCTAssertEqual(r.phase, .playing)
        r.ready(bottom)
        XCTAssertEqual(r.phase, .playing)
    }
}
