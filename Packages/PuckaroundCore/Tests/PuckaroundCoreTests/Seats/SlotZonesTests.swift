import XCTest

@testable import PuckaroundCore

/// Slot routing on a multi-hand table: a touch in a quadrant reaches the mallet
/// that keeps that quadrant, and a singles side hands its whole half to one.
final class SlotZonesTests: XCTestCase {
    private let table = Playfield(
        size: Vec2(120, 120), puckRadius: 4, malletRadius: 7, goalWidth: 36, restitution: 0.85,
        drag: 0.4, maxSpeed: 400, restSpeed: 0.5, faceoffBubbleRadius: 22, serveSpeed: 26)

    func testTwoVsTwoRoutesEachQuadrantToItsLane() {
        let zones = SeatZones(format: .twoVsTwo, bounds: table.bounds)
        XCTAssertEqual(
            zones.owner(of: Vec2(30, 100)), MalletSlot(side: .bottom, lane: .left),
            "bottom-left quadrant")
        XCTAssertEqual(
            zones.owner(of: Vec2(90, 100)), MalletSlot(side: .bottom, lane: .right),
            "bottom-right quadrant")
        XCTAssertEqual(
            zones.owner(of: Vec2(30, 20)), MalletSlot(side: .top, lane: .left), "top-left quadrant")
        XCTAssertEqual(
            zones.owner(of: Vec2(90, 20)), MalletSlot(side: .top, lane: .right),
            "top-right quadrant")
    }

    func testAMixedFormatSplitsOnlyTheDoublesSide() {
        // Bottom fields one hand, top two: the bottom half is one mallet's, the
        // top half splits at center-x.
        let zones = SeatZones(format: .oneVsTwo, bounds: table.bounds)
        XCTAssertEqual(zones.owner(of: Vec2(30, 100)), .bottomSingle)
        XCTAssertEqual(
            zones.owner(of: Vec2(90, 100)), .bottomSingle, "one hand owns the whole half")
        XCTAssertEqual(zones.owner(of: Vec2(30, 20)), MalletSlot(side: .top, lane: .left))
        XCTAssertEqual(zones.owner(of: Vec2(90, 20)), MalletSlot(side: .top, lane: .right))
    }

    func testSinglesGivesEachHalfToItsFullSlot() {
        let zones = SeatZones(format: .oneVsOne, bounds: table.bounds)
        // Anywhere in a half, either side of center-x, is that side's one mallet.
        XCTAssertEqual(zones.owner(of: Vec2(10, 90)), .bottomSingle)
        XCTAssertEqual(zones.owner(of: Vec2(110, 90)), .bottomSingle)
        XCTAssertEqual(zones.owner(of: Vec2(10, 30)), .topSingle)
        XCTAssertEqual(zones.owner(of: Vec2(110, 30)), .topSingle)
    }
}
