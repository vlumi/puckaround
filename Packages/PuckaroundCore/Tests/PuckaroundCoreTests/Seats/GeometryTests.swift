import XCTest

@testable import PuckaroundCore

/// The four-seat geometry that only the (unbuilt) 3–4 player tables exercise —
/// covered directly so a transposed width/height or a wrong inward vector can't
/// hide behind the duel-only game.
final class GeometryTests: XCTestCase {
    /// A square table, so left/right and top/bottom seats all fit.
    private let table = Playfield(
        size: Vec2(120, 120), puckRadius: 4, malletRadius: 7, goalWidth: 36, restitution: 0.85,
        drag: 0.4, maxSpeed: 400, restSpeed: 0.5, faceoffBubbleRadius: 22, serveSpeed: 26)

    func testEverySeatFacesTheMiddle() {
        XCTAssertEqual(Seat.bottom.inward, Vec2(0, -1))
        XCTAssertEqual(Seat.top.inward, Vec2(0, 1))
        XCTAssertEqual(Seat.left.inward, Vec2(1, 0))
        XCTAssertEqual(Seat.right.inward, Vec2(-1, 0))
    }

    func testMalletZonesSplitTheTableCorrectly() {
        let r = table.malletRadius
        let halfW = table.size.x / 2
        let halfH = table.size.y / 2

        let bottom = table.malletZone(for: .bottom)
        XCTAssertEqual(bottom.minX, r)
        XCTAssertEqual(bottom.width, table.size.x - 2 * r)
        XCTAssertEqual(bottom.minY, halfH + r, "bottom half only")

        let left = table.malletZone(for: .left)
        XCTAssertEqual(left.minX, r)
        XCTAssertEqual(left.width, halfW - 2 * r, "left half only")
        XCTAssertEqual(left.height, table.size.y - 2 * r, "full height")

        let right = table.malletZone(for: .right)
        XCTAssertEqual(right.minX, halfW + r, "right half only")
        XCTAssertEqual(right.width, halfW - 2 * r)
    }
}
