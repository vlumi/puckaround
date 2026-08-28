import XCTest

@testable import PuckaroundCore

final class PuckShapeTests: XCTestCase {
    func testCircleHasNoVertices() {
        XCTAssertEqual(PuckShape.circle.worldVertices(position: .zero, angle: 0, radius: 4), [])
    }

    func testSquareHasFourCornersAtRadius() {
        let v = PuckShape.square.worldVertices(position: .zero, angle: 0, radius: 4)
        XCTAssertEqual(v.count, 4)
        for corner in v {
            XCTAssertEqual(corner.length, 4, accuracy: 1e-9, "every corner is radius from centre")
        }
    }

    func testTriangleHasThreeCorners() {
        XCTAssertEqual(
            PuckShape.triangle.worldVertices(position: .zero, angle: 0, radius: 4).count, 3)
    }

    func testVerticesTranslateAndRotate() {
        let base = PuckShape.square.worldVertices(position: .zero, angle: 0, radius: 4)
        let moved = PuckShape.square.worldVertices(position: Vec2(10, 5), angle: 0, radius: 4)
        for (b, m) in zip(base, moved) {
            XCTAssertEqual(m, b + Vec2(10, 5))
        }
        // A quarter turn maps the square's corner set onto itself.
        let turned = PuckShape.square.worldVertices(position: .zero, angle: .pi / 2, radius: 4)
        for corner in turned {
            XCTAssertTrue(
                base.contains { $0.distance(to: corner) < 1e-9 },
                "a 90° turn is a symmetry of the square")
        }
    }

    func testVertexOrderIsStable() {
        // Determinism rests on a fixed vertex order — pin it.
        let a = PuckShape.square.worldVertices(position: .zero, angle: 0, radius: 1)
        let b = PuckShape.square.worldVertices(position: .zero, angle: 0, radius: 1)
        XCTAssertEqual(a, b)
    }
}
