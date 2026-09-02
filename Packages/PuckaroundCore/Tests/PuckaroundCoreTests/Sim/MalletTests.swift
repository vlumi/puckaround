import XCTest

@testable import PuckaroundCore

/// Mallets: where they may go, and what they do to the puck.
final class MalletTests: XCTestCase {
    private let bottom = MalletSlot.bottomSingle
    private let top = MalletSlot.topSingle

    private func rink() -> Rink {
        var r = Rink(table: .duel, seed: 1)
        r.startPlaying()
        r.park()
        r.place(Puck(position: r.table.center))
        return r
    }

    func testMalletsStartInTheirOwnHalves() {
        let r = Rink(table: .duel, seed: 1)
        XCTAssertGreaterThan(r.mallet(at: bottom)!.position.y, r.table.center.y)
        XCTAssertLessThan(r.mallet(at: top)!.position.y, r.table.center.y)
    }

    func testAMalletFollowsTheDrag() {
        var r = rink()
        r.placeMallet(at: bottom, position: r.table.malletZone(for: bottom).center)
        let from = r.mallet(at: bottom)!.position
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(-10, -5))])
        XCTAssertEqual(r.mallet(at: bottom)!.position, from + Vec2(-10, -5))
        XCTAssertEqual(r.mallet(at: bottom)!.velocity, Vec2(-10, -5) * Double(Rink.tickRate))
        r.advance(inputs: [:])
        XCTAssertEqual(r.mallet(at: bottom)!.velocity, .zero, "a still hand is a still mallet")
    }

    func testAGrabSnapsTheMalletToTheFinger() {
        var r = rink()
        r.placeMallet(at: bottom, position: Vec2(20, 150))
        let target = Vec2(60, 120)
        r.advance(inputs: [bottom: SeatInput(malletGrab: target)])
        XCTAssertEqual(r.mallet(at: bottom)!.position, target, "the mallet jumps under the finger")
    }

    func testAGrabIsClampedToTheZone() {
        var r = rink()
        // A grab aimed across the center line lands at the line, not over it.
        r.advance(inputs: [bottom: SeatInput(malletGrab: Vec2(50, 10))])
        XCTAssertEqual(
            r.mallet(at: bottom)!.position.y, r.table.center.y + r.table.malletRadius,
            "clamped to its own half")
    }

    func testAGrabDoesNotStrikeThePuckOnTheWayThere() {
        var r = rink()
        // Puck at center; mallet far away. A grab that lands ON the far side of
        // the puck must not swat it en route — placing the hand, not swinging.
        r.place(Puck(position: r.table.center, velocity: .zero))
        r.placeMallet(at: bottom, position: Vec2(90, 150))
        r.advance(inputs: [bottom: SeatInput(malletGrab: Vec2(50, 100))])
        XCTAssertEqual(r.puck.velocity, .zero, "the grab teleports past the puck without a hit")
    }

    func testAMalletCannotCrossTheCenterLineOrLeaveTheTable() {
        var r = rink()
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(-1000, -1000))])
        let m = r.mallet(at: bottom)!.position
        XCTAssertEqual(m.x, r.table.malletRadius)
        XCTAssertEqual(
            m.y, r.table.center.y + r.table.malletRadius, "touching the line, not over it")
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(1000, 1000))])
        XCTAssertEqual(
            r.mallet(at: bottom)!.position, Vec2(r.table.size.x, r.table.size.y) - Vec2(7, 7))
    }

    func testAMalletPushedIntoThePuckLaunchesIt() {
        var r = rink()
        // Park the mallet just below the puck, then shove it upward through it.
        let reach = r.table.puckRadius + r.table.malletRadius
        r.placeMallet(at: bottom, position: r.table.center + Vec2(0, reach + 1))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, -3))])
        XCTAssertLessThan(r.puck.velocity.y, 0, "the puck leaves away from the mallet")
        XCTAssertEqual(r.puck.velocity.x, 0, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(
            r.puck.position.distance(to: r.mallet(at: bottom)!.position), reach - 1e-9)
    }

    func testTheHitCarriesTheMalletsSpeedWithRestitution() {
        var r = rink()
        let reach = r.table.puckRadius + r.table.malletRadius
        // Exactly touching, then the mallet moves 1 unit into the puck.
        r.placeMallet(at: bottom, position: r.table.center + Vec2(0, reach))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, -1))])
        let malletSpeed = Double(Rink.tickRate)
        let struck = (1 + r.table.restitution) * malletSpeed
        let expected = struck * exp(-r.table.drag * Rink.dt) - r.table.friction * Rink.dt
        XCTAssertEqual(-r.puck.velocity.y, expected, accuracy: 1e-6)
    }

    func testAFastMalletCannotTunnelThroughThePuck() {
        var r = rink()
        // From well below the puck to well above it in a single tick.
        r.placeMallet(at: bottom, position: r.table.center + Vec2(0, 30))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, -25))])
        XCTAssertLessThan(
            r.puck.position.y, r.mallet(at: bottom)!.position.y,
            "the puck is ahead of the mallet, not behind it")
        XCTAssertLessThan(r.puck.velocity.y, 0)
    }

    func testAMovingPuckBouncesOffARestingMallet() {
        var r = rink()
        let m = r.mallet(at: bottom)!.position
        // Aim the puck straight down at the mallet from just above it.
        r.place(Puck(position: m - Vec2(0, 20), velocity: Vec2(0, 200)))
        var bounced = false
        for _ in 0..<Rink.tickRate {
            r.advance(inputs: [:])
            if r.puck.velocity.y < 0 {
                bounced = true
                break
            }
        }
        XCTAssertTrue(bounced)
        XCTAssertEqual(r.puck.velocity.x, 0, accuracy: 1e-9)
    }

    /// The reported "warp": slam the puck into a wall fast enough and it came
    /// out on the mallet's far side, moving backwards. The wall pushed it back
    /// through the mallet; now it slides along the wall instead.
    func testAPuckPinnedAgainstTheWallNeverPassesThroughTheMallet() {
        var r = rink()
        let wall = r.table.puckField.maxX
        r.place(Puck(position: Vec2(wall - 2, 120)))
        r.placeMallet(at: bottom, position: Vec2(wall - 30, 120))
        for _ in 0..<10 {
            r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(40, 0))])
            // Never punched clean through to the mallet's far (inner) side —
            // it stays within a mallet's reach of the wall side, not flung to
            // the center — and never off the table.
            XCTAssertGreaterThan(
                r.puck.position.x, r.mallet(at: bottom)!.position.x - r.table.malletRadius,
                "the puck never tunnels past the mallet")
            XCTAssertTrue(r.table.puckField.contains(r.puck.position))
        }
        // It is not left pinned dead on the wall: the squeeze gives it a real
        // inward nudge, so it comes off the boards and slides, never stuck.
        XCTAssertLessThan(r.puck.position.x, wall - 1, "the puck is nudged off the wall")
        XCTAssertGreaterThan(
            abs(r.puck.position.y - 120), r.table.puckRadius, "and it slid along it")
    }

    /// The same squeeze in a corner keeps the puck inside the field.
    func testACornerSqueezeKeepsThePuckOnTheTable() {
        var r = rink()
        let field = r.table.puckField
        r.place(Puck(position: Vec2(field.maxX - 1, field.maxY - 1)))
        r.placeMallet(at: bottom, position: Vec2(field.maxX - 20, field.maxY - 20))
        for _ in 0..<10 {
            r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(30, 30))])
            XCTAssertTrue(field.contains(r.puck.position), "\(r.puck.position)")
        }
    }

    func testSlotsOutsideTheFormatAreIgnored() {
        var r = rink()
        let before = r
        // A lane the singles table never fields — the sim drops its input.
        r.advance(inputs: [
            MalletSlot(side: .bottom, lane: .left): SeatInput(malletDrag: Vec2(10, 10))
        ])
        XCTAssertEqual(r.mallets, before.mallets)
    }
}
