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
}
