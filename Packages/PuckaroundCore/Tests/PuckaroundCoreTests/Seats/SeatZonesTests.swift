import XCTest

@testable import PuckaroundCore

final class SeatZonesTests: XCTestCase {
    /// A square table, so every edge is the same distance from the centre.
    let table = Playfield(
        size: Vec2(120, 120), puckRadius: 4, malletRadius: 7, goalWidth: 36, restitution: 0.85,
        drag: 0.4, maxSpeed: 400, restSpeed: 0.5)
    var four: SeatZones { SeatZones(lineup: Lineup(playerCount: 4)!, bounds: table.bounds) }

    func testOwnerIsTheNearestSeatedEdge() {
        XCTAssertEqual(four.owner(of: Vec2(60, 110)), PlayerID(0), "near the bottom")
        XCTAssertEqual(four.owner(of: Vec2(60, 10)), PlayerID(1), "near the top")
        XCTAssertEqual(four.owner(of: Vec2(10, 60)), PlayerID(2), "near the left")
        XCTAssertEqual(four.owner(of: Vec2(110, 60)), PlayerID(3), "near the right")
    }

    func testUnseatedEdgesNeverOwn() {
        let duel = SeatZones(lineup: .duel, bounds: Playfield.duel.bounds)
        // Hard against the left wall, which nobody sits at: the nearer of the
        // two seated edges wins.
        XCTAssertEqual(duel.owner(of: Vec2(0, 150)), PlayerID(0))
        XCTAssertEqual(duel.owner(of: Vec2(0, 10)), PlayerID(1))
    }

    func testTiesGoToTheLowerSeat() {
        XCTAssertEqual(four.owner(of: table.center), PlayerID(0))
    }

    func testPointsOutsideTheTableStillBelongToSomeone() {
        XCTAssertEqual(four.owner(of: Vec2(60, 500)), PlayerID(0))
        XCTAssertEqual(four.owner(of: Vec2(-50, 60)), PlayerID(2))
    }

    func testBandsHugTheirEdges() {
        let depth = 10.0
        let bottom = four.band(for: PlayerID(0), depth: depth)
        XCTAssertEqual(bottom.maxY, table.size.y)
        XCTAssertEqual(bottom.height, depth)
        XCTAssertEqual(bottom.width, table.size.x)
        let right = four.band(for: PlayerID(3), depth: depth)
        XCTAssertEqual(right.maxX, table.size.x)
        XCTAssertEqual(right.width, depth)
        XCTAssertEqual(right.height, table.size.y)
        XCTAssertEqual(four.band(for: PlayerID(1), depth: depth).minY, 0)
        XCTAssertEqual(four.band(for: PlayerID(2), depth: depth).minX, 0)
    }
}
