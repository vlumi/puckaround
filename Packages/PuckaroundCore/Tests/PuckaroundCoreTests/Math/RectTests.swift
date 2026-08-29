import XCTest

@testable import PuckaroundCore

final class RectTests: XCTestCase {
    let rect = Rect(x: 10, y: 20, width: 100, height: 50)

    func testEdgesAndCenter() {
        XCTAssertEqual(rect.maxX, 110)
        XCTAssertEqual(rect.maxY, 70)
        XCTAssertEqual(rect.center, Vec2(60, 45))
    }

    func testInsetAndClamping() {
        let inner = rect.insetBy(5)
        XCTAssertEqual(inner, Rect(x: 15, y: 25, width: 90, height: 40))
        XCTAssertEqual(rect.clamping(Vec2(-5, 100)), Vec2(10, 70))
        XCTAssertEqual(rect.clamping(Vec2(50, 30)), Vec2(50, 30))
    }

    func testContainsIsEdgeInclusive() {
        XCTAssertTrue(rect.contains(Vec2(10, 20)))
        XCTAssertTrue(rect.contains(Vec2(110, 70)))
        XCTAssertFalse(rect.contains(Vec2(110.01, 70)))
    }

    func testEdgeProximity() {
        XCTAssertTrue(rect.isAtLeftEdge(Vec2(10, 45)))
        XCTAssertFalse(rect.isAtLeftEdge(Vec2(11, 45)))
        XCTAssertTrue(rect.isAtRightEdge(Vec2(110, 45)))
        XCTAssertFalse(rect.isAtRightEdge(Vec2(109, 45)))
        XCTAssertTrue(rect.isAtTopEdge(Vec2(60, 20)))
        XCTAssertFalse(rect.isAtTopEdge(Vec2(60, 21)))
        XCTAssertTrue(rect.isAtBottomEdge(Vec2(60, 70)))
        XCTAssertFalse(rect.isAtBottomEdge(Vec2(60, 69)))
        // A hair past still counts (float dust from clamping).
        XCTAssertTrue(rect.isAtLeftEdge(Vec2(10 - 1e-9, 45)))
    }
}
