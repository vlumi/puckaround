import XCTest

@testable import PuckaroundCore

/// The rotating-polygon puck (Spike 1): it spins, tumbles off walls, and — the
/// non-negotiable — stays deterministic.
final class ShapedPuckTests: XCTestCase {
    private let bottom = PlayerID(0)
    private let top = PlayerID(1)

    private var squareTable: Playfield {
        var t = Playfield.duel
        t.puckShape = .square
        return t
    }

    private func rink(_ table: Playfield) -> Rink {
        var r = Rink(table: table, lineup: .duel, seed: 1)
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

    func testACornerHitOnAWallImpartsSpin() {
        var r = rink(squareTable)
        // Rotate the square 45° so a CORNER leads, and fire it at the top wall
        // off to one side so the corner strikes asymmetrically.
        r.place(
            Puck(
                position: Vec2(30, 20), velocity: Vec2(0, -220), angle: .pi / 4,
                angularVelocity: 0))
        for _ in 0..<Rink.tickRate {
            r.advance(inputs: [:])
            if abs(r.puck.angularVelocity) > 0.01 { break }
        }
        XCTAssertGreaterThan(abs(r.puck.angularVelocity), 0.01, "a corner hit should spin it")
    }

    func testAGlancingMalletHitSpinsAShapedPuck() {
        var r = rink(squareTable)
        r.place(Puck(position: r.table.center))
        let reach = r.table.puckRadius + r.table.malletRadius
        // Mallet approaches from below and to the side, sweeping sideways — a
        // glancing hit, which should put spin on the square.
        r.placeMallet(of: bottom, at: r.table.center + Vec2(0, reach - 0.5))
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
            var r = Rink(table: squareTable, lineup: .duel, seed: 9)
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
            var r = Rink(table: t, lineup: .duel, seed: 3)
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
            // The CENTRE can leave through a goal mouth; otherwise it stays in.
            let out = !r.table.puckField.insetBy(-2).contains(r.puck.position)
            if out {
                XCTAssertTrue(
                    r.table.isInGoalMouth(x: r.puck.position.x), "only escapes via a goal")
            }
        }
    }
}
