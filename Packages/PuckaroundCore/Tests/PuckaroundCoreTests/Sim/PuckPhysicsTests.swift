import XCTest

@testable import PuckaroundCore

/// The puck alone: drag, walls, the speed cap. Mallets and goals have their
/// own suites.
final class PuckPhysicsTests: XCTestCase {
    /// A rink with the puck placed and pushed by hand, mallets parked in their
    /// far corners so nothing but the walls is in play.
    private func rink(puckAt position: Vec2, velocity: Vec2) -> Rink {
        var r = Rink(table: .duel, seed: 1)
        r.startPlaying()
        r.park()
        r.place(Puck(position: position, velocity: velocity))
        return r
    }

    func testDragBringsThePuckToRest() {
        var r = rink(puckAt: Playfield.duel.center, velocity: Vec2(0, 30))
        XCTAssertTrue(r.puck.isMoving)
        for _ in 0..<(Rink.tickRate * 30) {
            r.advance(inputs: [:])
        }
        XCTAssertFalse(r.puck.isMoving, "thirty seconds of drag must stop a gentle push")
    }

    func testDragIsExponentialPerTick() {
        var r = rink(puckAt: Playfield.duel.center, velocity: Vec2(100, 0))
        r.advance(inputs: [:])
        XCTAssertEqual(r.puck.velocity.length, 100 * exp(-r.table.drag * Rink.dt), accuracy: 1e-9)
        XCTAssertEqual(r.puck.velocity.normalized, Vec2(1, 0))
    }

    func testSideWallBounceMirrorsAndLoses() {
        var r = rink(puckAt: Playfield.duel.center, velocity: Vec2(200, 0))
        var bounced = false
        var speedBefore = 0.0
        for _ in 0..<Rink.tickRate {
            speedBefore = r.puck.velocity.length
            r.advance(inputs: [:])
            if r.puck.velocity.x < 0 {
                bounced = true
                break
            }
        }
        XCTAssertTrue(bounced)
        XCTAssertEqual(r.puck.velocity.y, 0, "a head-on bounce keeps the tangent")
        let expected = speedBefore * exp(-r.table.drag * Rink.dt) * r.table.restitution
        XCTAssertEqual(r.puck.velocity.length, expected, accuracy: 1e-9)
    }

    func testThePuckNeverLeavesTheFieldExceptThroughAGoal() {
        var r = rink(puckAt: Playfield.duel.center, velocity: .zero)
        var rng = SeededRNG(seed: 99)
        let field = r.table.puckField
        var goals = 0
        for tick in 0..<(Rink.tickRate * 20) {
            if tick % 10 == 0 {
                // A violent random push from wherever the puck is.
                let angle = Double.random(in: 0..<(2 * .pi), using: &rng)
                let speed = Double.random(in: 100...5000, using: &rng)
                r.place(Puck(position: r.puck.position, velocity: Vec2(angle: angle) * speed))
            }
            let before = r.score
            r.advance(inputs: [:])
            if r.score != before {
                goals += 1
            }
            if r.finalWinner != nil {
                break  // a goal ended the game → rematch faceoff, puck frozen
            }
            // A puck heading into a goal is legitimately past the boards; only
            // one NOT lined up with a mouth must stay inside.
            let inAMouth =
                r.table.isInGoalMouth(x: r.puck.position.x, of: .top)
                || r.table.isInGoalMouth(x: r.puck.position.x, of: .bottom)
            if !inAMouth {
                XCTAssertTrue(
                    field.contains(r.puck.position), "escaped at tick \(tick): \(r.puck.position)")
            }
            XCTAssertLessThanOrEqual(r.puck.velocity.length, r.table.maxSpeed + 1e-9)
        }
        XCTAssertGreaterThan(goals, 0, "twenty seconds of random violence should find a goal")
    }

    func testTheSpeedCapHolds() {
        var r = rink(puckAt: Playfield.duel.center, velocity: Vec2(0, 100_000))
        r.advance(inputs: [:])
        XCTAssertLessThanOrEqual(r.puck.velocity.length, r.table.maxSpeed)
    }
}
