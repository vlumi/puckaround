import XCTest

@testable import PuckaroundCore

final class SwipeControlTests: XCTestCase {
    private let table = Playfield.square
    private var four: Lineup { Lineup(playerCount: 4)! }

    private func source() -> SwipeControlSource {
        SwipeControlSource(zones: SeatZones(lineup: four, bounds: table.bounds))
    }

    func testMovementBecomesOneSwipeThenNothing() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(60, 110), time: 0)
        s.touchMoved(id: 1, at: Vec2(60, 100), time: 0.1)
        s.touchMoved(id: 1, at: Vec2(60, 90), time: 0.2)
        let input = s.input(for: PlayerID(0), at: 0)
        XCTAssertEqual(input.swipe?.from, Vec2(60, 110))
        XCTAssertEqual(input.swipe?.to, Vec2(60, 90))
        XCTAssertEqual(input.swipe!.velocity.x, 0, accuracy: 1e-9)
        XCTAssertEqual(input.swipe!.velocity.y, -100, accuracy: 1e-9)
        XCTAssertEqual(s.input(for: PlayerID(0), at: 1), .none, "consumed")
    }

    func testAFingerBelongsToTheSeatItBeganIn() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(60, 115), time: 0)  // bottom seat
        s.touchMoved(id: 1, at: Vec2(60, 5), time: 0.5)  // ends by the top seat
        XCTAssertEqual(s.input(for: PlayerID(1), at: 0), .none)
        XCTAssertNotNil(s.input(for: PlayerID(0), at: 0).swipe)
    }

    func testAStillFingerSwipesNothing() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(60, 110), time: 0)
        XCTAssertEqual(s.input(for: PlayerID(0), at: 0), .none)
        s.touchMoved(id: 1, at: Vec2(60, 110), time: 0)
        XCTAssertEqual(
            s.input(for: PlayerID(0), at: 1), .none, "zero elapsed time is not a velocity")
    }

    func testALiftedFingersLastMovementStillLands() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(60, 110), time: 0)
        s.touchMoved(id: 1, at: Vec2(60, 80), time: 0.1)
        s.touchEnded(id: 1)
        XCTAssertNotNil(s.input(for: PlayerID(0), at: 0).swipe)
        XCTAssertEqual(s.input(for: PlayerID(0), at: 1), .none)
        // The id is forgotten with it: a later move under it is nobody's.
        s.touchMoved(id: 1, at: Vec2(60, 50), time: 0.2)
        XCTAssertEqual(s.input(for: PlayerID(0), at: 2), .none)
    }

    func testTheLongestSweepOfASeatWinsTheTick() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(30, 115), time: 0)
        s.touchBegan(id: 2, at: Vec2(90, 115), time: 0)
        s.touchMoved(id: 1, at: Vec2(30, 110), time: 0.1)
        s.touchMoved(id: 2, at: Vec2(90, 60), time: 0.1)
        XCTAssertEqual(s.input(for: PlayerID(0), at: 0).swipe?.to, Vec2(90, 60))
        XCTAssertEqual(
            s.input(for: PlayerID(0), at: 1).swipe?.to, Vec2(30, 110), "the other waits a tick")
    }

    func testReleaseAllForgetsEverything() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(60, 110), time: 0)
        s.touchMoved(id: 1, at: Vec2(60, 80), time: 0.1)
        s.releaseAll()
        XCTAssertEqual(s.input(for: PlayerID(0), at: 0), .none)
        s.touchMoved(id: 1, at: Vec2(60, 50), time: 0.2)
        XCTAssertEqual(s.input(for: PlayerID(0), at: 1), .none)
    }

    func testUnknownTouchMovesAreIgnored() {
        let s = source()
        s.touchMoved(id: 9, at: Vec2(60, 50), time: 0.2)
        s.touchEnded(id: 9)
        for player in four.players {
            XCTAssertEqual(s.input(for: player, at: 0), .none)
        }
    }
}
