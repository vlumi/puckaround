import XCTest

@testable import PuckaroundCore

final class MalletControlTests: XCTestCase {
    private let table = Playfield.duel
    private let bottom = MalletSlot.bottomSingle
    private let top = MalletSlot.topSingle

    private func source() -> MalletControlSource {
        MalletControlSource(zones: SeatZones(format: .oneVsOne, bounds: table.bounds))
    }

    func testMovementBecomesOneDragThenNothing() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(50, 120))
        s.touchMoved(id: 1, at: Vec2(55, 110))
        s.touchMoved(id: 1, at: Vec2(60, 100))
        XCTAssertEqual(s.input(for: bottom, at: 0), SeatInput(malletDrag: Vec2(10, -20)))
        XCTAssertEqual(s.input(for: bottom, at: 1), .none, "consumed")
    }

    func testAFingerBelongsToTheSlotItBeganIn() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(50, 120))  // bottom half
        s.touchMoved(id: 1, at: Vec2(50, 20))  // crosses into the top half
        XCTAssertEqual(s.input(for: top, at: 0), .none)
        XCTAssertEqual(s.input(for: bottom, at: 0).malletDrag, Vec2(0, -100))
    }

    func testOnlyTheFirstFingerDrivesTheMallet() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(30, 120))
        s.touchBegan(id: 2, at: Vec2(70, 120))
        s.touchMoved(id: 2, at: Vec2(70, 100))
        XCTAssertEqual(s.input(for: bottom, at: 0), .none, "the second finger is ignored")
        s.touchMoved(id: 1, at: Vec2(30, 110))
        XCTAssertEqual(s.input(for: bottom, at: 1).malletDrag, Vec2(0, -10))
        // Once the driver lifts, a NEW finger may take over — the ignored one stays ignored.
        s.touchEnded(id: 1)
        s.touchMoved(id: 2, at: Vec2(70, 90))
        XCTAssertEqual(s.input(for: bottom, at: 2), .none)
        s.touchBegan(id: 3, at: Vec2(50, 120))
        s.touchMoved(id: 3, at: Vec2(50, 118))
        XCTAssertEqual(s.input(for: bottom, at: 3).malletDrag, Vec2(0, -2))
    }

    func testEachSlotHasItsOwnFinger() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(50, 120))
        s.touchBegan(id: 2, at: Vec2(50, 40))
        s.touchMoved(id: 1, at: Vec2(51, 120))
        s.touchMoved(id: 2, at: Vec2(50, 42))
        XCTAssertEqual(s.input(for: bottom, at: 0).malletDrag, Vec2(1, 0))
        XCTAssertEqual(s.input(for: top, at: 0).malletDrag, Vec2(0, 2))
    }

    func testAStillFingerDragsNothing() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(50, 120))
        XCTAssertEqual(s.input(for: bottom, at: 0), .none)
        s.touchMoved(id: 1, at: Vec2(50, 120))
        XCTAssertEqual(s.input(for: bottom, at: 1), .none)
    }

    func testALiftedFingersLastMovementStillLands() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(50, 120))
        s.touchMoved(id: 1, at: Vec2(50, 90))
        s.touchEnded(id: 1)
        XCTAssertEqual(s.input(for: bottom, at: 0).malletDrag, Vec2(0, -30))
        XCTAssertEqual(s.input(for: bottom, at: 1), .none)
        // The id is forgotten with it: a later move under it is nobody's.
        s.touchMoved(id: 1, at: Vec2(50, 50))
        XCTAssertEqual(s.input(for: bottom, at: 2), .none)
    }

    func testReleaseAllForgetsEverything() {
        let s = source()
        s.touchBegan(id: 1, at: Vec2(50, 120))
        s.touchMoved(id: 1, at: Vec2(50, 90))
        s.releaseAll()
        XCTAssertEqual(s.input(for: bottom, at: 0), .none)
        s.touchMoved(id: 1, at: Vec2(50, 50))
        XCTAssertEqual(s.input(for: bottom, at: 1), .none)
    }

    func testUnknownTouchMovesAreIgnored() {
        let s = source()
        s.touchMoved(id: 9, at: Vec2(60, 50))
        s.touchEnded(id: 9)
        XCTAssertEqual(s.input(for: bottom, at: 0), .none)
        XCTAssertEqual(s.input(for: top, at: 0), .none)
    }
}
