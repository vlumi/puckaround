import XCTest

@testable import PuckaroundCore
@testable import PuckaroundKit

/// The stored setup resolving to a concrete table: fixed picks pass through,
/// "?" rolls per game, and the separate "?" rolls stay independent.
final class SetupTests: XCTestCase {
    func testFixedPicksIgnoreTheRoll() {
        var s = Setup()
        s.puckShapeKey = PuckShapeKey.triangle.rawValue
        s.puckCount = 2
        s.wrapWalls = true
        XCTAssertEqual(s.resolvedPucks(roll: 7), [.triangle, .triangle])
        XCTAssertEqual(s.resolvedWalls(roll: 7), .wrap)
    }

    /// A stale or bad stored key must not crash the table.
    func testABadStoredShapeFallsBackToTheDisc() {
        var s = Setup()
        s.puckShapeKey = "hexagon"
        XCTAssertEqual(s.resolvedPucks(roll: 0), [.circle])
    }

    func testARandomPuckCanRollEveryShape() {
        var s = Setup()
        s.randomPuck = true
        let rolled = (0..<PuckShapeKey.allCases.count).map { s.resolvedPucks(roll: UInt64($0))[0] }
        for key in PuckShapeKey.allCases {
            XCTAssertTrue(rolled.contains(key.shape))
        }
    }

    /// With the shape on "?", every puck rolls its own — a mixed table.
    func testEachRandomPuckRollsItsOwnShape() {
        var s = Setup()
        s.randomPuck = true
        s.puckCount = 3
        // roll 36 = 0b100100: slices 0b00, 0b01·2… land on circle, circle, triangle.
        XCTAssertEqual(s.resolvedPucks(roll: 36), [.circle, .circle, .triangle])
    }

    func testARandomCountRollsOneToThree() {
        var s = Setup()
        s.randomPuckCount = true
        XCTAssertEqual(s.resolvedPucks(roll: 0).count, 1)
        XCTAssertEqual(s.resolvedPucks(roll: 1 << 16).count, 2)
        XCTAssertEqual(s.resolvedPucks(roll: 2 << 16).count, 3)
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
        XCTAssertEqual(s.resolvedPucks(roll: a), s.resolvedPucks(roll: b))
        XCTAssertNotEqual(s.resolvedWalls(roll: a), s.resolvedWalls(roll: b))
    }
}
