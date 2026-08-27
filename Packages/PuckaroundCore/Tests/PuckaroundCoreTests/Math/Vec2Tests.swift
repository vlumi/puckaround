import XCTest

@testable import PuckaroundCore

final class Vec2Tests: XCTestCase {
    func testLengthAndNormalization() {
        let v = Vec2(3, 4)
        XCTAssertEqual(v.length, 5)
        XCTAssertEqual(v.normalized, Vec2(0.6, 0.8))
        XCTAssertEqual(Vec2.zero.normalized, .zero, "zero must not divide by zero")
    }

    func testArithmetic() {
        var v = Vec2(1, 2)
        v += Vec2(2, 3)
        v *= 2
        XCTAssertEqual(v, Vec2(6, 10))
        XCTAssertEqual(-v, Vec2(-6, -10))
        XCTAssertEqual(Vec2(1, 0).dot(Vec2(0, 1)), 0)
    }

    func testAngleIsYDown() {
        let down = Vec2(angle: .pi / 2)
        XCTAssertEqual(down.x, 0, accuracy: 1e-12)
        XCTAssertEqual(down.y, 1, accuracy: 1e-12)
    }

    func testDistanceToSegmentClampsToEndpoints() {
        let a = Vec2(0, 0)
        let b = Vec2(10, 0)
        XCTAssertEqual(Vec2(5, 3).distance(toSegment: a, b), 3)
        XCTAssertEqual(Vec2(-4, 0).distance(toSegment: a, b), 4)
        XCTAssertEqual(Vec2(13, 4).distance(toSegment: a, b), 5)
        XCTAssertEqual(
            Vec2(2, 2).distance(toSegment: a, a), Vec2(2, 2).length,
            "a degenerate segment is a point")
    }
}
