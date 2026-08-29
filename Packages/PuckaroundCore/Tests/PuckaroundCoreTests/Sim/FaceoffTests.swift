import XCTest

@testable import PuckaroundCore

/// The opening ceremony: puck frozen at centre behind a force field, mallets
/// held out of the bubble, play beginning the instant every slot readies.
final class FaceoffTests: XCTestCase {
    private let bottom = MalletSlot.bottomSingle
    private let top = MalletSlot.topSingle

    private func rink() -> Rink {
        var r = Rink(table: .duel, seed: 1)
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
            r.mallet(at: bottom)!.position.distance(to: r.puck.position), keepOut - 1e-6,
            "the mallet is held at the force-field rim")
    }

    func testAMalletIsFreeOutsideTheBubble() {
        var r = rink()
        let home = r.table.malletZone(for: bottom).center
        r.placeMallet(at: bottom, position: home)
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(5, 3))])
        // Well away from the puck, so it moves exactly as asked.
        XCTAssertEqual(r.mallet(at: bottom)!.position, home + Vec2(5, 3))
    }

    func testTheFieldDropsAndPlayIsLiveOnReady() {
        var r = rink()
        r.startPlaying()
        XCTAssertFalse(r.isFaceoff)
        // Now a mallet may drive right up to (and strike) the puck.
        r.placeMallet(
            at: bottom,
            position: r.table.center + Vec2(0, r.table.puckRadius + r.table.malletRadius))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, -3))])
        XCTAssertTrue(r.puck.isMoving, "the field is gone; the puck can be struck")
    }

    func testEveryNewGameOpensAFreshFaceoff() {
        var r = Rink(table: .duel, rules: Rules(pointsToWin: 1), seed: 1)
        r.startPlaying()
        r.park()
        // End the game: drive the puck fully through the bottom goal.
        r.place(
            Puck(
                position: Vec2(r.table.center.x, r.table.puckField.maxY - 1), velocity: Vec2(0, 300)
            ))
        for _ in 0..<6 where !r.isFaceoff { r.advance(inputs: [:]) }
        // A win opens a rematch faceoff remembering the winner…
        XCTAssertTrue(r.isFaceoff)
        XCTAssertEqual(r.finalWinner, .top)
        // …and a full new game clears that, a fresh faceoff with no result shown.
        r.newGame()
        XCTAssertTrue(r.isFaceoff)
        XCTAssertNil(r.finalWinner)
        XCTAssertEqual(r.readyMallets, [])
    }

    func testNoReadyMalletsOncePlaying() {
        var r = rink()
        r.startPlaying()
        XCTAssertFalse(r.isFaceoff)
        XCTAssertEqual(r.readyMallets, [], "readyMallets is empty during play")
    }
}
