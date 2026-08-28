import XCTest

@testable import PuckaroundCore

/// The wall response in isolation — both the bounce and the grazing
/// (no-approach) path, and the deterministic vertex tie-break.
final class PolygonCollisionTests: XCTestCase {
    /// A unit square, corner-up, hitting the top wall (outward normal (0,-1),
    /// at y = 0) from just below.
    private func body(velocity: Vec2, angle: Double = 0, spin: Double = 0) -> PolygonCollision.Body
    {
        PolygonCollision.Body(
            shape: .square, center: Vec2(0, 0.5), angle: angle, radius: 1, velocity: velocity,
            angularVelocity: spin)
    }
    private let topWall = PolygonCollision.Wall(normal: Vec2(0, -1), limit: 0)

    func testACircleHasNoPolygonContact() {
        // A circle carries no vertices, so the polygon path never resolves it
        // (the circle uses its own reflection). The guard returns nil.
        let circle = PolygonCollision.Body(
            shape: .circle, center: .zero, angle: 0, radius: 1, velocity: Vec2(0, -10),
            angularVelocity: 0)
        XCTAssertNil(PolygonCollision.resolve(circle, wall: topWall, restitution: 0.85))
    }

    func testNoContactReturnsNil() {
        // Well clear of the wall — not penetrating.
        let far = PolygonCollision.Body(
            shape: .square, center: Vec2(0, 50), angle: 0, radius: 1, velocity: Vec2(0, -10),
            angularVelocity: 0)
        XCTAssertNil(PolygonCollision.resolve(far, wall: topWall, restitution: 0.85))
    }

    func testAHeadOnBounceReflectsAndKeepsSpeed() {
        let result = PolygonCollision.resolve(
            body(velocity: Vec2(0, -100)), wall: topWall, restitution: 0.85)
        let out = try? XCTUnwrap(result)
        XCTAssertEqual(out?.velocity.y ?? 0, 85, accuracy: 1e-6, "reflected, restitution applied")
        XCTAssertEqual(out?.velocity.x ?? -1, 0, accuracy: 1e-9, "no sideways change on a flat hit")
        XCTAssertEqual(out?.impactSpeed ?? 0, 100, accuracy: 1e-6)
    }

    func testAGrazingContactUnpenetratesWithoutBouncing() {
        // Penetrating but moving ALONG the wall, not into it — no bounce.
        let result = PolygonCollision.resolve(
            body(velocity: Vec2(50, 0)), wall: topWall, restitution: 0.85)
        let out = try? XCTUnwrap(result)
        XCTAssertEqual(out?.velocity ?? .zero, Vec2(50, 0), "velocity unchanged when only grazing")
        XCTAssertEqual(out?.impactSpeed ?? -1, 0, "no impact recorded")
    }

    func testResolveIsDeterministic() {
        let b = body(velocity: Vec2(7, -120), angle: 0.3, spin: 6)
        XCTAssertEqual(
            PolygonCollision.resolve(b, wall: topWall, restitution: 0.85),
            PolygonCollision.resolve(b, wall: topWall, restitution: 0.85))
    }
}
