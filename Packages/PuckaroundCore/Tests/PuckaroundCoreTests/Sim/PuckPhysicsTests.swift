import XCTest

@testable import PuckaroundCore

final class PuckPhysicsTests: XCTestCase {
    private func rink(_ table: Playfield = .duel) -> Rink {
        Rink(table: table, lineup: .duel, seed: 1)
    }

    /// A swipe that sweeps straight through the puck's centre.
    private func swipeThroughCenter(of table: Playfield, velocity: Vec2) -> SeatInput {
        let c = table.center
        return SeatInput(
            swipe: Swipe(from: c - Vec2(20, 0), to: c + Vec2(20, 0), velocity: velocity))
    }

    /// Drag rescales the velocity each tick, so "unchanged direction" is a
    /// floating-point comparison, not an exact one.
    private func assertSameDirection(
        _ a: Vec2, _ b: Vec2, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(a.normalized.x, b.normalized.x, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(a.normalized.y, b.normalized.y, accuracy: 1e-9, file: file, line: line)
    }

    func testServePutsThePuckAtCentreMoving() {
        let r = rink()
        XCTAssertEqual(r.puck.position, r.table.center)
        XCTAssertEqual(r.puck.velocity.length, r.table.serveSpeed, accuracy: 1e-9)
    }

    func testSwipeThroughThePuckGivesItTheFingersVelocity() {
        var r = rink()
        let hit = swipeThroughCenter(of: r.table, velocity: Vec2(100, 0))
        r.advance(inputs: [PlayerID(0): hit])
        // One tick of drag has applied since; the direction is the finger's.
        XCTAssertEqual(r.puck.velocity.normalized, Vec2(1, 0))
        XCTAssertEqual(r.puck.velocity.length, 100 * exp(-r.table.drag * Rink.dt), accuracy: 1e-9)
    }

    func testSwipeThatMissesDoesNothing() {
        var r = rink()
        let before = r.puck.velocity
        let c = r.table.center
        let reach = r.table.puckRadius + r.table.fingerRadius
        let miss = SeatInput(
            swipe: Swipe(
                from: Vec2(c.x - 20, c.y + reach + 1), to: Vec2(c.x + 20, c.y + reach + 1),
                velocity: Vec2(100, 0)))
        r.advance(inputs: [PlayerID(0): miss])
        assertSameDirection(r.puck.velocity, before)
    }

    func testStrikesLandInLineupOrder() {
        var r = rink()
        let first = swipeThroughCenter(of: r.table, velocity: Vec2(50, 0))
        let second = swipeThroughCenter(of: r.table, velocity: Vec2(0, 50))
        r.advance(inputs: [PlayerID(1): second, PlayerID(0): first])
        XCTAssertEqual(
            r.puck.velocity.normalized, Vec2(0, 1), "the higher seat's strike lands last")
    }

    func testSeatsOutsideTheLineupAreIgnored() {
        var r = rink()
        let before = r.puck.velocity
        r.advance(inputs: [PlayerID(3): swipeThroughCenter(of: r.table, velocity: Vec2(100, 0))])
        assertSameDirection(r.puck.velocity, before)
    }

    func testDragBringsThePuckToRest() {
        var r = rink()
        r.advance(inputs: [PlayerID(0): swipeThroughCenter(of: r.table, velocity: Vec2(0, 30))])
        XCTAssertTrue(r.puck.isMoving)
        for _ in 0..<(Rink.tickRate * 30) {
            r.advance(inputs: [:])
        }
        XCTAssertFalse(r.puck.isMoving, "thirty seconds of drag must stop a gentle push")
    }

    func testWallBounceMirrorsAndLoses() {
        var r = rink()
        // Fire it straight at the right wall from the centre.
        r.advance(inputs: [PlayerID(0): swipeThroughCenter(of: r.table, velocity: Vec2(200, 0))])
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

    func testThePuckNeverLeavesTheField() {
        var r = rink()
        var rng = SeededRNG(seed: 99)
        let field = r.table.puckField
        for tick in 0..<(Rink.tickRate * 20) {
            var inputs: [PlayerID: SeatInput] = [:]
            if tick % 10 == 0 {
                // A violent random strike from wherever the puck is.
                let angle = Double.random(in: 0..<(2 * .pi), using: &rng)
                let speed = Double.random(in: 100...5000, using: &rng)
                let c = r.puck.position
                inputs[PlayerID(0)] = SeatInput(
                    swipe: Swipe(
                        from: c, to: c + Vec2(angle: angle), velocity: Vec2(angle: angle) * speed))
            }
            r.advance(inputs: inputs)
            XCTAssertTrue(
                field.contains(r.puck.position), "escaped at tick \(tick): \(r.puck.position)")
            XCTAssertLessThanOrEqual(r.puck.velocity.length, r.table.maxSpeed + 1e-9)
        }
    }

    func testStandardTableFollowsTheLineup() {
        XCTAssertEqual(Playfield.standard(for: .duel), .duel)
        XCTAssertEqual(Playfield.standard(for: Lineup(playerCount: 3)!), .square)
        XCTAssertEqual(Playfield.standard(for: Lineup(playerCount: 4, teamed: true)!), .square)
        XCTAssertEqual(
            Playfield.duel.puckField, Playfield.duel.bounds.insetBy(Playfield.duel.puckRadius))
    }
}
