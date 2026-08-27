import XCTest

@testable import PuckaroundCore

/// Mallets: where they may go, and what they do to the puck.
final class MalletTests: XCTestCase {
    private let bottom = PlayerID(0)
    private let top = PlayerID(1)

    private func rink() -> Rink {
        var r = Rink(table: .duel, lineup: .duel, seed: 1)
        r.park()
        r.place(Puck(position: r.table.center))
        return r
    }

    func testMalletsStartInTheirOwnHalves() {
        let r = Rink(table: .duel, lineup: .duel, seed: 1)
        XCTAssertGreaterThan(r.mallet(of: bottom).position.y, r.table.center.y)
        XCTAssertLessThan(r.mallet(of: top).position.y, r.table.center.y)
    }

    func testAMalletFollowsTheDrag() {
        var r = rink()
        r.placeMallet(of: bottom, at: r.table.malletZone(for: .bottom).center)
        let from = r.mallet(of: bottom).position
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(-10, -5))])
        XCTAssertEqual(r.mallet(of: bottom).position, from + Vec2(-10, -5))
        XCTAssertEqual(r.mallet(of: bottom).velocity, Vec2(-10, -5) * Double(Rink.tickRate))
        r.advance(inputs: [:])
        XCTAssertEqual(r.mallet(of: bottom).velocity, .zero, "a still hand is a still mallet")
    }

    func testAMalletCannotCrossTheCentreLineOrLeaveTheTable() {
        var r = rink()
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(-1000, -1000))])
        let m = r.mallet(of: bottom).position
        XCTAssertEqual(m.x, r.table.malletRadius)
        XCTAssertEqual(
            m.y, r.table.center.y + r.table.malletRadius, "touching the line, not over it")
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(1000, 1000))])
        XCTAssertEqual(
            r.mallet(of: bottom).position, Vec2(r.table.size.x, r.table.size.y) - Vec2(7, 7))
    }

    func testAMalletPushedIntoThePuckLaunchesIt() {
        var r = rink()
        // Park the mallet just below the puck, then shove it upward through it.
        let reach = r.table.puckRadius + r.table.malletRadius
        r.placeMallet(of: bottom, at: r.table.center + Vec2(0, reach + 1))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, -3))])
        XCTAssertLessThan(r.puck.velocity.y, 0, "the puck leaves away from the mallet")
        XCTAssertEqual(r.puck.velocity.x, 0, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(
            r.puck.position.distance(to: r.mallet(of: bottom).position), reach - 1e-9)
    }

    func testTheHitCarriesTheMalletsSpeedWithRestitution() {
        var r = rink()
        let reach = r.table.puckRadius + r.table.malletRadius
        // Exactly touching, then the mallet moves 1 unit into the puck.
        r.placeMallet(of: bottom, at: r.table.center + Vec2(0, reach))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, -1))])
        let malletSpeed = Double(Rink.tickRate)
        let expected = (1 + r.table.restitution) * malletSpeed * exp(-r.table.drag * Rink.dt)
        XCTAssertEqual(-r.puck.velocity.y, expected, accuracy: 1e-6)
    }

    func testAFastMalletCannotTunnelThroughThePuck() {
        var r = rink()
        // From well below the puck to well above it in a single tick.
        r.placeMallet(of: bottom, at: r.table.center + Vec2(0, 30))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, -25))])
        XCTAssertLessThan(
            r.puck.position.y, r.mallet(of: bottom).position.y,
            "the puck is ahead of the mallet, not behind it")
        XCTAssertLessThan(r.puck.velocity.y, 0)
    }

    func testAMovingPuckBouncesOffARestingMallet() {
        var r = rink()
        let m = r.mallet(of: bottom).position
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

    func testSeatsOutsideTheLineupAreIgnored() {
        var r = rink()
        let before = r
        r.advance(inputs: [PlayerID(3): SeatInput(malletDrag: Vec2(10, 10))])
        XCTAssertEqual(r.mallets, before.mallets)
    }
}
