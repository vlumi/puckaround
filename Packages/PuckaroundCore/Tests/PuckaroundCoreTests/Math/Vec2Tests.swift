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
}
