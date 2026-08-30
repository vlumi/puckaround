import XCTest

@testable import PuckaroundCore
@testable import PuckaroundKit

/// The stored setup resolving to a concrete table: fixed picks pass through,
/// "?" rolls per game, and the two "?" rolls stay independent of each other.
final class SetupTests: XCTestCase {
    func testFixedPicksIgnoreTheRoll() {
        var s = Setup()
        s.puckShapeKey = PuckShapeKey.triangle.rawValue
        s.wrapWalls = true
        XCTAssertEqual(s.resolvedPuck(roll: 7), PuckShapeKey.triangle.shape)
        XCTAssertEqual(s.resolvedWalls(roll: 7), .wrap)
    }

    /// A stale or bad stored key must not crash the table.
    func testABadStoredShapeFallsBackToTheDisc() {
        var s = Setup()
        s.puckShapeKey = "hexagon"
        XCTAssertEqual(s.resolvedPuck(roll: 0), .circle)
    }

    func testARandomPuckCanRollEveryShape() {
        var s = Setup()
        s.randomPuck = true
        let rolled = (0..<PuckShapeKey.allCases.count).map { s.resolvedPuck(roll: UInt64($0)) }
        for key in PuckShapeKey.allCases {
            XCTAssertTrue(rolled.contains(key.shape))
        }
    }

    func testRandomWallsFlipOnTheHighBit() {
        var s = Setup()
        s.randomWalls = true
        XCTAssertEqual(s.resolvedWalls(roll: 0), .solid)
        XCTAssertEqual(s.resolvedWalls(roll: 1 << 32), .wrap)
    }

    /// With both "?" on, the walls flip must not be a function of the shape roll
    /// — otherwise wrap could only ever pair with some of the shapes.
    func testTheTwoRandomRollsAreIndependent() {
        var s = Setup()
        s.randomPuck = true
        s.randomWalls = true
        // 3 << 32 keeps roll % 3 == 0 (same shape as roll 0) but sets bit 32.
        let a: UInt64 = 0
        let b: UInt64 = 3 << 32
        XCTAssertEqual(s.resolvedPuck(roll: a), s.resolvedPuck(roll: b))
        XCTAssertNotEqual(s.resolvedWalls(roll: a), s.resolvedWalls(roll: b))
    }
}
