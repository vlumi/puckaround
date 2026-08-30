import XCTest

@testable import PuckaroundCore

final class SeatZonesTests: XCTestCase {
    /// A square table, so both halves are the same size.
    let table = Playfield(
        size: Vec2(120, 120), puckRadius: 4, malletRadius: 7, goalWidth: 36, restitution: 0.85,
        drag: 0.4, maxSpeed: 400, restSpeed: 0.5, faceoffBubbleRadius: 22, serveSpeed: 26)
    var duel: SeatZones { SeatZones(format: .oneVsOne, bounds: table.bounds) }

    func testOwnerIsTheSideTheTouchFallsIn() {
        XCTAssertEqual(duel.owner(of: Vec2(60, 110)), .bottomSingle, "near the bottom")
        XCTAssertEqual(duel.owner(of: Vec2(60, 10)), .topSingle, "near the top")
    }

    func testAnyPointInAHalfRoutesToThatSidesSingle() {
        // Hard against a side wall, off-center — still the half's one mallet.
        XCTAssertEqual(duel.owner(of: Vec2(0, 90)), .bottomSingle)
        XCTAssertEqual(duel.owner(of: Vec2(119, 30)), .topSingle)
    }

    func testTheCenterLineGoesToTheBottom() {
        XCTAssertEqual(duel.owner(of: table.center), .bottomSingle)
    }

    func testPointsOutsideTheTableStillBelongToSomeone() {
        XCTAssertEqual(duel.owner(of: Vec2(60, 500)), .bottomSingle)
        XCTAssertEqual(duel.owner(of: Vec2(60, -50)), .topSingle)
    }
}
