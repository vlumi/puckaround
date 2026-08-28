import XCTest

@testable import PuckaroundCore

/// The opening ceremony: puck frozen at centre behind a force field, mallets
/// held out of the bubble, play beginning the instant every seat readies.
final class FaceoffTests: XCTestCase {
    private let bottom = PlayerID(0)
    private let top = PlayerID(1)

    private func rink() -> Rink {
        var r = Rink(table: .duel, lineup: .duel, seed: 1)
        r.park()
        return r
    }

    func testTheGameOpensFrozenInAFaceoff() {
        let r = rink()
        XCTAssertTrue(r.isFaceoff)
        XCTAssertEqual(r.puck.position, r.table.center)
        XCTAssertFalse(r.puck.isMoving)
    }

    func testThePuckStaysFrozenUntilEveryoneReadies() {
        var r = rink()
        for _ in 0..<30 {
            r.advance(inputs: [
                bottom: SeatInput(malletDrag: Vec2(0, -20)),
                top: SeatInput(malletDrag: Vec2(0, 20)),
            ])
        }
        XCTAssertEqual(r.puck.position, r.table.center, "no mallet reached it through the field")
        XCTAssertFalse(r.puck.isMoving)
        XCTAssertTrue(r.isFaceoff)
    }

    func testReadyingEveryoneBeginsPlayImmediately() {
        var r = rink()
        r.ready(bottom)
        XCTAssertTrue(r.isFaceoff)
        r.ready(top)
        XCTAssertEqual(r.phase, .playing)
    }

    func testAMalletCannotEnterTheBubbleDuringFaceoff() {
        var r = rink()
        // Drive the bottom mallet straight at the puck, hard, for a while.
        for _ in 0..<40 {
            r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, -30))])
        }
        let keepOut = r.table.faceoffBubbleRadius + r.table.malletRadius
        XCTAssertGreaterThanOrEqual(
            r.mallet(of: bottom).position.distance(to: r.puck.position), keepOut - 1e-6,
            "the mallet is held at the force-field rim")
    }

    func testAMalletIsFreeOutsideTheBubble() {
        var r = rink()
        let home = r.table.malletZone(for: .bottom).center
        r.placeMallet(of: bottom, at: home)
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(5, 3))])
        // Well away from the puck, so it moves exactly as asked.
        XCTAssertEqual(r.mallet(of: bottom).position, home + Vec2(5, 3))
    }

    func testTheFieldDropsAndPlayIsLiveOnReady() {
        var r = rink()
        r.startPlaying()
        XCTAssertFalse(r.isFaceoff)
        // Now a mallet may drive right up to (and strike) the puck.
        r.placeMallet(
            of: bottom, at: r.table.center + Vec2(0, r.table.puckRadius + r.table.malletRadius))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, -3))])
        XCTAssertTrue(r.puck.isMoving, "the field is gone; the puck can be struck")
    }

    func testEveryNewGameOpensAFreshFaceoff() {
        var r = Rink(table: .duel, lineup: .duel, rules: Rules(pointsToWin: 1), seed: 1)
        r.startPlaying()
        r.park()
        // End the game.
        let y = r.table.puckField.maxY - 1
        r.place(Puck(position: Vec2(r.table.center.x, y), velocity: Vec2(0, 300)))
        r.advance(inputs: [:])
        // A win opens a rematch faceoff remembering the winner…
        XCTAssertTrue(r.isFaceoff)
        XCTAssertEqual(r.finalWinner, top)
        // …and a full new game clears that, a fresh faceoff with no result shown.
        r.newGame()
        XCTAssertTrue(r.isFaceoff)
        XCTAssertNil(r.finalWinner)
        XCTAssertEqual(r.readySeats, [])
    }
}
