import XCTest

@testable import PuckaroundCore

/// Spin on the ROUND puck: english off a glancing mallet hit, a wall bounce that
/// the spin skews and the wall bleeds — gentler than a polygon, and still
/// deterministic. The disc is the default table, so this guards the common case.
final class DiscSpinTests: XCTestCase {
    private let bottom = MalletSlot.bottomSingle

    private func discRink() -> Rink {
        var r = Rink(table: .duel, seed: 1)  // .duel is a circle
        r.startPlaying()
        r.park()
        return r
    }

    func testAGlancingMalletHitSpinsTheDisc() {
        var r = discRink()
        r.place(Puck(position: r.table.center))
        let reach = r.table.puckRadius + r.table.malletRadius
        r.placeMallet(at: bottom, position: r.table.center + Vec2(0, reach - 0.5))
        // A sideways sweep into the puck — english.
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(4, -2))])
        XCTAssertNotEqual(r.puck.angularVelocity, 0, "a glancing hit puts english on the disc")
    }

    func testTheDiscTakesLessSpinThanASquareFromTheSameHit() {
        func spinAfterHit(_ shape: PuckShape) -> Double {
            var t = Playfield.duel
            t.puckShape = shape
            var r = Rink(table: t, seed: 1)
            r.startPlaying()
            r.park()
            r.place(Puck(position: r.table.center))
            let reach = r.table.puckRadius + r.table.malletRadius
            r.placeMallet(at: bottom, position: r.table.center + Vec2(0, reach - 0.5))
            r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(4, -2))])
            return abs(r.puck.angularVelocity)
        }
        XCTAssertLessThan(
            spinAfterHit(.circle), spinAfterHit(.square),
            "the disc bites less than a square from an identical glancing hit")
    }

    func testANonSpinningDiscBouncesStraight() {
        // No spin → a plain mirror bounce: a straight-down shot comes straight
        // back up, no sideways deflection.
        var r = discRink()
        r.place(Puck(position: Vec2(20, 30), velocity: Vec2(0, -200)))
        for _ in 0..<Rink.tickRate where r.puck.velocity.y <= 0 {
            r.advance(inputs: [:])
        }
        XCTAssertGreaterThan(r.puck.velocity.y, 0, "it bounced back up")
        XCTAssertEqual(r.puck.velocity.x, 0, accuracy: 1e-9, "no spin, no sideways skew")
    }

    func testSpinSteersTheDiscBounceOffAxis() {
        // A spinning disc's outgoing direction deflects to one side; the opposite
        // spin deflects it the other way. A straight-down shot off the top wall.
        func bounceDirection(spin: Double) -> Double {
            var r = discRink()
            r.place(Puck(position: Vec2(20, 30), velocity: Vec2(0, -200), angularVelocity: spin))
            for _ in 0..<Rink.tickRate where r.puck.velocity.y <= 0 {
                r.advance(inputs: [:])
            }
            return atan2(r.puck.velocity.y, r.puck.velocity.x)
        }
        let left = bounceDirection(spin: 12)
        let right = bounceDirection(spin: -12)
        XCTAssertGreaterThan(abs(left - right), 0.01, "spin sign steers the disc's bounce")
    }

    func testTheDiscSteerStaysGentle() {
        // Even a hard spin only nudges the disc's bounce a few degrees — a
        // finesse effect, not a hard curve (a flat wall can't roll it along).
        var r = discRink()
        r.place(Puck(position: Vec2(20, 30), velocity: Vec2(0, -200), angularVelocity: 12))
        let inAngle = atan2(r.puck.velocity.y, r.puck.velocity.x)
        for _ in 0..<Rink.tickRate where r.puck.velocity.y <= 0 {
            r.advance(inputs: [:])
        }
        // The reflected direction is roughly -inAngle (mirror in y); the steer is
        // the extra rotation on top. With spin 12 and 0.015/rad that's ~0.18 rad.
        let outAngle = atan2(r.puck.velocity.y, r.puck.velocity.x)
        let mirror = -inAngle  // pure disc reflection off the horizontal wall
        let skew = abs(atan2(sin(outAngle - mirror), cos(outAngle - mirror)))
        XCTAssertGreaterThan(skew, 0.02, "spin does steer the bounce")
        XCTAssertLessThan(skew, 0.35, "but only gently — a few degrees, not a hook")
    }

    func testAWallBounceBleedsSomeDiscSpin() {
        var r = discRink()
        r.place(Puck(position: Vec2(20, 30), velocity: Vec2(0, -200), angularVelocity: 10))
        let before = abs(r.puck.angularVelocity)
        for _ in 0..<Rink.tickRate where r.puck.velocity.y <= 0 {
            r.advance(inputs: [:])
        }
        let after = abs(r.puck.angularVelocity)
        XCTAssertLessThan(after, before, "the wall's grip bleeds some spin")
        XCTAssertGreaterThan(after, 0, "but not all of it")
    }

    func testDiscSpinStaysDeterministic() {
        func run() -> Rink {
            var r = Rink(table: .duel, seed: 7)
            r.startPlaying()
            r.park()
            r.place(Puck(position: Vec2(28, 44), velocity: Vec2(150, 190), angularVelocity: 8))
            for _ in 0..<1200 { r.advance(inputs: [:]) }
            return r
        }
        XCTAssertEqual(run(), run())
    }
}
