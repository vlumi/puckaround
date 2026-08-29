import XCTest

@testable import PuckaroundCore

/// The rotating-polygon puck (Spike 1): it spins, tumbles off walls, and — the
/// non-negotiable — stays deterministic.
final class ShapedPuckTests: XCTestCase {
    private let bottom = MalletSlot.bottomSingle
    private let top = MalletSlot.topSingle

    private var squareTable: Playfield {
        var t = Playfield.duel
        t.puckShape = .square
        return t
    }

    private func rink(_ table: Playfield) -> Rink {
        var r = Rink(table: table, seed: 1)
        r.startPlaying()
        r.park()
        return r
    }

    func testTheDefaultTableIsStillACircle() {
        XCTAssertEqual(Playfield.duel.puckShape, .circle)
    }

    func testASquarePuckBouncesOffAWall() {
        var r = rink(squareTable)
        // Off to the side of the goal mouth, so it bounces rather than scores.
        r.place(Puck(position: Vec2(12, 20), velocity: Vec2(0, -200)))
        var bounced = false
        for _ in 0..<Rink.tickRate {
            r.advance(inputs: [:])
            if r.puck.velocity.y > 0 { bounced = true; break }
        }
        XCTAssertTrue(bounced, "a square puck must bounce off the top wall")
        XCTAssertTrue(r.table.puckField.insetBy(-1).contains(r.puck.position))
    }

    func testSpinSteersTheBounceOffAxis() {
        // A spinning puck's outgoing direction deflects to one side; the OTHER
        // spin deflects it the other way — the erratic character of a shaped
        // puck. A non-spinning one bounces straight (like a disc), so the two
        // spun bounces must differ from each other.
        func bounceDirection(spin: Double) -> Double {
            var r = rink(squareTable)
            // Tilted so a corner (not a flat face) meets the wall off-center —
            // that lever is what the spin steers against.
            r.place(
                Puck(
                    position: Vec2(20, 20), velocity: Vec2(6, -160), angle: 0.35,
                    angularVelocity: spin))
            var out = r.puck.velocity
            for _ in 0..<Rink.tickRate {
                r.advance(inputs: [:])
                if r.puck.velocity.y > 0 {
                    out = r.puck.velocity
                    break
                }
            }
            return atan2(out.y, out.x)
        }
        let left = bounceDirection(spin: 12)
        let right = bounceDirection(spin: -12)
        XCTAssertNotEqual(left, right, accuracy: 0, "spin sign must steer the bounce")
        XCTAssertGreaterThan(abs(left - right), 0.02, "and by a visible amount")
    }

    func testANonSpinningCornerHitStartsAlittleSpinButBouncesLikeADisc() {
        // A flat-on hit: no spin starts, and the bounce is the disc reflection.
        var flat = rink(squareTable)
        flat.place(Puck(position: Vec2(20, 20), velocity: Vec2(0, -160)))
        for _ in 0..<Rink.tickRate {
            flat.advance(inputs: [:])
            if flat.puck.velocity.y > 0 { break }
        }
        XCTAssertEqual(flat.puck.angularVelocity, 0, "a flat face starts no spin")
        // A tilted corner hit from rest: it picks up SOME spin (the corner
        // catches), but the outgoing direction is still close to the disc bounce.
        var tilt = rink(squareTable)
        tilt.place(Puck(position: Vec2(20, 20), velocity: Vec2(0, -160), angle: 0.35))
        for _ in 0..<Rink.tickRate {
            tilt.advance(inputs: [:])
            if tilt.puck.velocity.y > 0 { break }
        }
        XCTAssertNotEqual(tilt.puck.angularVelocity, 0, "a corner catch starts a tumble")
        // Both reflect a downward shot back upward at a disc-like angle.
        XCTAssertGreaterThan(tilt.puck.velocity.y, 0, "still bounces off the wall")
    }

    func testABounceKeepsMostOfTheSpin() {
        // The bounce spends a little spin to steer, but doesn't dump it — a
        // spinning puck keeps tumbling after hitting a wall.
        var r = rink(squareTable)
        r.place(Puck(position: Vec2(20, 20), velocity: Vec2(0, -160), angularVelocity: 10))
        for _ in 0..<Rink.tickRate {
            r.advance(inputs: [:])
            if r.puck.velocity.y > 0 { break }
        }
        XCTAssertGreaterThan(abs(r.puck.angularVelocity), 4, "most of the spin carries through")
    }

    func testAGlancingMalletHitSpinsAShapedPuck() {
        var r = rink(squareTable)
        r.place(Puck(position: r.table.center))
        let reach = r.table.puckRadius + r.table.malletRadius
        // Mallet approaches from below and to the side, sweeping sideways — a
        // glancing hit, which should put spin on the square.
        r.placeMallet(at: bottom, position: r.table.center + Vec2(0, reach - 0.5))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(4, -2))])
        XCTAssertNotEqual(r.puck.angularVelocity, 0, "a glancing hit puts english on it")
    }

    func testSpinDecaysToRest() {
        var r = rink(squareTable)
        r.place(Puck(position: r.table.center, angularVelocity: 5))
        for _ in 0..<(Rink.tickRate * 60) {
            r.advance(inputs: [:])
        }
        XCTAssertEqual(r.puck.angularVelocity, 0, "friction stops the spin")
    }

    func testASquarePuckRunIsDeterministic() {
        func run() -> [Puck] {
            var r = Rink(table: squareTable, seed: 9)
            r.startPlaying()
            r.park()
            // Launch it spinning and moving, then let it ricochet — this is the
            // path that must be bit-identical run to run.
            r.place(Puck(position: Vec2(28, 44), velocity: Vec2(150, 190), angularVelocity: 3))
            var trail: [Puck] = []
            for _ in 0..<1200 {
                r.advance(inputs: [:])
                trail.append(r.puck)
            }
            return trail
        }
        let a = run()
        let b = run()
        if let tick = Array(zip(a, b)).firstIndex(where: { $0 != $1 }) {
            XCTFail("square-puck runs diverged at tick \(tick) of 1200")
        }
        XCTAssertEqual(a.last, b.last)
        // The run actually exercised rotation.
        XCTAssertTrue(a.contains { $0.angle != 0 }, "the puck rotated during the run")
    }

    func testATriangleAlsoTumblesDeterministically() {
        var t = Playfield.duel
        t.puckShape = .triangle
        func run() -> Rink {
            var r = Rink(table: t, seed: 3)
            r.startPlaying(); r.park()
            r.place(Puck(position: Vec2(30, 40), velocity: Vec2(120, 90), angularVelocity: 2))
            for _ in 0..<600 { r.advance(inputs: [:]) }
            return r
        }
        XCTAssertEqual(run(), run())
    }

    func testAShapedPuckStaysOnTheTable() {
        var r = rink(squareTable)
        var rng = SeededRNG(seed: 5)
        for _ in 0..<(Rink.tickRate * 20) {
            let a = Double.random(in: 0..<(2 * .pi), using: &rng)
            let s = Double.random(in: 100...4000, using: &rng)
            r.place(
                Puck(
                    position: r.puck.position, velocity: Vec2(angle: a) * s,
                    angle: r.puck.angle, angularVelocity: Double.random(in: -10...10, using: &rng)))
            r.advance(inputs: [:])
            // The CENTER can leave through a goal mouth; otherwise it stays in.
            let out = !r.table.puckField.insetBy(-2).contains(r.puck.position)
            if out {
                let inAMouth =
                    r.table.goal(.top).admitsMouth(r.puck.position.x)
                    || r.table.goal(.bottom).admitsMouth(r.puck.position.x)
                XCTAssertTrue(inAMouth, "only escapes via a goal")
            }
        }
    }
}
