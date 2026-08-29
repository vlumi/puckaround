import XCTest

@testable import PuckaroundCore

final class MalletControlTests: XCTestCase {
    private let table = Playfield.duel
    private let bottom = MalletSlot.bottomSingle
    private let top = MalletSlot.topSingle
    /// Where the mallets sit for these tests — one in each half.
    private let bottomMallet = Vec2(50, 120)
    private let topMallet = Vec2(50, 40)

    private func source() -> MalletControlSource {
        MalletControlSource(zones: SeatZones(format: .oneVsOne, bounds: table.bounds))
    }

    func testAGrabSnapsTheMalletUnderTheFingerThenDrags() {
        let s = source()
        // Land right on the mallet — a grab. First input carries the snap, then
        // the movement since is the drag.
        s.touchBegan(id: 1, at: Vec2(52, 118), malletAt: bottomMallet)
        s.touchMoved(id: 1, at: Vec2(60, 100), malletAt: bottomMallet)
        let first = s.input(for: bottom, at: 0)
        XCTAssertEqual(first.malletGrab, Vec2(52, 118), "the grab snaps to the finger")
        XCTAssertEqual(first.malletDrag, Vec2(8, -18), "then follows the movement")
        XCTAssertEqual(s.input(for: bottom, at: 1), .none, "consumed")
    }

    func testAFingerLandingFarFromTheMalletIsIgnored() {
        let s = source()
        // Down in the bottom half but nowhere near the mallet: no grab.
        s.touchBegan(id: 1, at: Vec2(10, 155), malletAt: bottomMallet)
        s.touchMoved(id: 1, at: Vec2(12, 150), malletAt: bottomMallet)
        XCTAssertEqual(s.input(for: bottom, at: 0), .none, "a far finger doesn't drive the mallet")
    }

    func testAFingerCanSlideIntoRangeAndGrab() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(10, 155), malletAt: bottomMallet)  // too far
        XCTAssertEqual(s.input(for: bottom, at: 0), .none)
        // Slides near the mallet — now it grabs.
        s.touchMoved(id: 1, at: Vec2(48, 122), malletAt: bottomMallet)
        XCTAssertEqual(s.input(for: bottom, at: 1).malletGrab, Vec2(48, 122), "sliding in grabs it")
    }

    func testAFingerKeepsTheMalletWhereverItWanders() {
        let s = source()
        s.touchBegan(id: 1, at: bottomMallet, malletAt: bottomMallet)
        _ = s.input(for: bottom, at: 0)  // consume the grab
        // Crossing toward the center line still drives THIS mallet, not the top.
        s.touchMoved(id: 1, at: Vec2(50, 82), malletAt: bottomMallet)
        XCTAssertEqual(s.input(for: top, at: 1), .none)
        XCTAssertEqual(s.input(for: bottom, at: 1).malletDrag, Vec2(0, -38))
    }

    func testOnlyOneFingerDrivesAMallet() {
        let s = source()
        s.touchBegan(id: 1, at: bottomMallet, malletAt: bottomMallet)
        // A second finger near the same mallet is ignored — one already has it.
        s.touchBegan(id: 2, at: Vec2(53, 120), malletAt: bottomMallet)
        _ = s.input(for: bottom, at: 0)
        s.touchMoved(id: 2, at: Vec2(60, 120), malletAt: bottomMallet)
        XCTAssertEqual(s.input(for: bottom, at: 1), .none, "the second finger is ignored")
        s.touchMoved(id: 1, at: Vec2(48, 120), malletAt: bottomMallet)
        XCTAssertEqual(s.input(for: bottom, at: 2).malletDrag, Vec2(-2, 0))
    }

    func testEachMalletHasItsOwnFinger() {
        let s = source()
        s.touchBegan(id: 1, at: bottomMallet, malletAt: bottomMallet)
        s.touchBegan(id: 2, at: topMallet, malletAt: topMallet)
        _ = s.input(for: bottom, at: 0)
        _ = s.input(for: top, at: 0)
        s.touchMoved(id: 1, at: Vec2(51, 120), malletAt: bottomMallet)
        s.touchMoved(id: 2, at: Vec2(50, 42), malletAt: topMallet)
        XCTAssertEqual(s.input(for: bottom, at: 1).malletDrag, Vec2(1, 0))
        XCTAssertEqual(s.input(for: top, at: 1).malletDrag, Vec2(0, 2))
    }

    func testALiftedFingersLastMovementStillLands() {
        let s = source()
        s.touchBegan(id: 1, at: bottomMallet, malletAt: bottomMallet)
        _ = s.input(for: bottom, at: 0)
        s.touchMoved(id: 1, at: Vec2(50, 90), malletAt: bottomMallet)
        s.touchEnded(id: 1)
        XCTAssertEqual(s.input(for: bottom, at: 1).malletDrag, Vec2(0, -30))
        XCTAssertEqual(s.input(for: bottom, at: 2), .none)
        // The id is forgotten with it: a later move under it is nobody's.
        s.touchMoved(id: 1, at: Vec2(50, 50), malletAt: bottomMallet)
        XCTAssertEqual(s.input(for: bottom, at: 3), .none)
    }

    func testReleaseAllForgetsEverything() {
        let s = source()
        s.touchBegan(id: 1, at: bottomMallet, malletAt: bottomMallet)
        s.touchMoved(id: 1, at: Vec2(50, 90), malletAt: bottomMallet)
        s.releaseAll()
        XCTAssertEqual(s.input(for: bottom, at: 0), .none)
        s.touchMoved(id: 1, at: Vec2(50, 50), malletAt: bottomMallet)
        XCTAssertEqual(s.input(for: bottom, at: 1), .none)
    }

    func testUnknownTouchMovesFarFromAnyMalletAreIgnored() {
        let s = source()
        s.touchMoved(id: 9, at: Vec2(10, 155), malletAt: bottomMallet)
        s.touchEnded(id: 9)
        XCTAssertEqual(s.input(for: bottom, at: 0), .none)
        XCTAssertEqual(s.input(for: top, at: 0), .none)
    }
}
