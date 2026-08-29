import XCTest

@testable import PuckaroundCore

/// Goals, serves, and the end of a game.
final class ScoringTests: XCTestCase {
    private let bottom = MalletSlot.bottomSingle
    private let top = MalletSlot.topSingle

    private func rink(rules: Rules = .standard) -> Rink {
        var r = Rink(table: .duel, rules: rules, seed: 1)
        r.startPlaying()
        r.park()
        return r
    }

    /// Fires the puck at a short wall on `side`, from just inside it, and steps
    /// once — which scores and serves in the same tick, so the served puck read
    /// after this has already glided one step into the conceder's half.
    private func shoot(_ r: inout Rink, at side: Side, x: Double) {
        let y = side == .top ? r.table.puckField.minY + 1 : r.table.puckField.maxY - 1
        r.place(Puck(position: Vec2(x, y), velocity: Vec2(0, side == .top ? -300 : 300)))
        // A goal counts only once the whole puck is past the line, so drive it
        // in — until it scores, or a few ticks pass (a post hit that bounces).
        let before = r.score
        for _ in 0..<6 {
            r.advance(inputs: [:])
            if r.score != before { break }
        }
    }

    func testAGameOpensWithAFaceoffAtCentre() {
        let r = Rink(table: .duel, seed: 1)
        XCTAssertEqual(r.score, [0, 0])
        XCTAssertTrue(r.isFaceoff)
        XCTAssertEqual(r.readyMallets, [])
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
        XCTAssertEqual(r.score(of: .bottom), 1)
        XCTAssertEqual(r.score(of: .top), 0)
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

    func testAGoalNeedsTheWholePuckPastTheLine() {
        var r = rink()
        // Nose just over the line, the puck not yet fully in — not a goal.
        r.place(
            Puck(position: Vec2(r.table.center.x, r.table.puckField.minY), velocity: Vec2(0, -1)))
        r.advance(inputs: [:])
        XCTAssertEqual(r.score, [0, 0], "a nose over the line is not a goal")
        // Fully past the line — it counts.
        r.place(
            Puck(position: Vec2(r.table.center.x, r.table.topGoalLine - 1), velocity: Vec2(0, -1)))
        r.advance(inputs: [:])
        XCTAssertEqual(r.score, [1, 0], "the whole puck across the line is a goal")
    }

    func testWinningOpensARematchFaceoffShowingTheResult() {
        var r = rink(rules: Rules(pointsToWin: 2))
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertEqual(r.phase, .playing)
        shoot(&r, at: .bottom, x: r.table.center.x)
        // The win goes straight to a faceoff that remembers the winner, so the
        // result stays on screen while the players decide on a rematch.
        XCTAssertTrue(r.isFaceoff)
        XCTAssertEqual(r.finalWinner, .top)
        XCTAssertEqual(r.score, [0, 2], "the final score is kept for display")
        XCTAssertEqual(r.puck.position, r.table.center)
        XCTAssertFalse(r.puck.isMoving, "frozen behind the field")
    }

    func testReadyingUpAfterAWinIsTheRematchAndResetsTheScore() {
        var r = rink(rules: Rules(pointsToWin: 2))
        shoot(&r, at: .bottom, x: r.table.center.x)
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertEqual(r.finalWinner, .top)
        r.ready(bottom)
        XCTAssertEqual(r.score, [0, 2], "score holds until the rematch actually starts")
        r.ready(top)
        XCTAssertEqual(r.phase, .playing, "both readied → the rematch is on")
        XCTAssertEqual(r.score, [0, 0], "and the score resets as it starts")
        XCTAssertNil(r.finalWinner)
    }

    func testTheRematchFaceoffPuckIsUntouchableUntilReady() {
        var r = rink(rules: Rules(pointsToWin: 1))
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertTrue(r.isFaceoff)
        // Drive the bottom mallet at the frozen puck — the field holds it out.
        for _ in 0..<20 {
            r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, -20))])
        }
        XCTAssertEqual(r.puck.position, r.table.center)
        XCTAssertFalse(r.puck.isMoving)
    }

    func testNewGameResetsTheScoreAndOpensAFreshFaceoffLeavingTheMallets() {
        var r = rink(rules: Rules(pointsToWin: 1))
        shoot(&r, at: .bottom, x: r.table.center.x)
        XCTAssertEqual(r.finalWinner, .top)
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(3, -3))])
        let hands = r.mallets
        r.newGame()
        XCTAssertEqual(r.score, [0, 0])
        XCTAssertTrue(r.isFaceoff)
        XCTAssertNil(r.finalWinner, "a fresh game shows no prior result")
        XCTAssertEqual(r.puck.position, r.table.center)
        XCTAssertEqual(r.mallets, hands, "the mallets are where the hands left them")
    }

    func testReadyingBothSeatsStartsPlay() {
        var r = Rink(table: .duel, seed: 1)
        r.ready(bottom)
        XCTAssertTrue(r.isFaceoff, "one slot readied is not enough")
        XCTAssertEqual(r.readyMallets, [bottom])
        r.ready(top)
        XCTAssertEqual(r.phase, .playing, "both readied → play begins")
    }

    func testReadyIsALatchWithNoTakeBacks() {
        var r = Rink(table: .duel, seed: 1)
        r.ready(bottom)
        r.ready(bottom)  // idempotent
        XCTAssertEqual(r.readyMallets, [bottom])
        // Once playing, readying does nothing.
        r.ready(top)
        XCTAssertEqual(r.phase, .playing)
        r.ready(bottom)
        XCTAssertEqual(r.phase, .playing)
    }
}
