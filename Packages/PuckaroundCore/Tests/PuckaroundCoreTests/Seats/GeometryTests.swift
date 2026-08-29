import XCTest

@testable import PuckaroundCore

/// Side and mallet-zone geometry — covered directly so a transposed
/// width/height or a wrong inward vector can't hide behind the duel-only game.
final class GeometryTests: XCTestCase {
    /// A square table, so a transposed half is obvious.
    private let table = Playfield(
        size: Vec2(120, 120), puckRadius: 4, malletRadius: 7, goalWidth: 36, restitution: 0.85,
        drag: 0.4, maxSpeed: 400, restSpeed: 0.5, faceoffBubbleRadius: 22, serveSpeed: 26)

    func testEverySideFacesTheMiddle() {
        XCTAssertEqual(Side.bottom.inward, Vec2(0, -1))
        XCTAssertEqual(Side.top.inward, Vec2(0, 1))
        XCTAssertEqual(Side.bottom.inward, -Side.top.inward)
    }

    func testSinglesMalletZonesSplitTheHalves() {
        let r = table.malletRadius
        let halfH = table.size.y / 2

        let bottom = table.malletZone(for: .bottomSingle)
        XCTAssertEqual(bottom.minX, r)
        XCTAssertEqual(bottom.width, table.size.x - 2 * r)
        XCTAssertEqual(bottom.minY, halfH + r, "bottom half only")

        let top = table.malletZone(for: .topSingle)
        XCTAssertEqual(top.minX, r)
        XCTAssertEqual(top.width, table.size.x - 2 * r)
        XCTAssertEqual(top.minY, r, "top half only")
        XCTAssertEqual(top.maxY, halfH - r)
    }
}
