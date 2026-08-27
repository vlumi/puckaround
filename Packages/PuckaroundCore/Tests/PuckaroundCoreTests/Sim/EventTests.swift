import XCTest

@testable import PuckaroundCore

/// The `GameEvent` stream the sound and haptics consume — a pure function of
/// the sim, so these run headless.
final class EventTests: XCTestCase {
    private let bottom = PlayerID(0)
    private let top = PlayerID(1)

    private func rink(rules: Rules = .standard) -> Rink {
        var r = Rink(table: .duel, lineup: .duel, rules: rules, seed: 1)
        r.park()
        r.place(Puck(position: r.table.center))
        return r
    }

    func testEventsAreClearedEachTick() {
        var r = rink()
        r.place(Puck(position: r.table.center, velocity: Vec2(200, 0)))
        var sawSome = false
        for _ in 0..<Rink.tickRate {
            r.advance(inputs: [:])
            if !r.events.isEmpty { sawSome = true }
        }
        XCTAssertTrue(sawSome, "a bouncing puck should raise wall events")
        // Park it dead centre, still: a quiet tick has no events.
        r.place(Puck(position: r.table.center))
        r.advance(inputs: [:])
        XCTAssertEqual(r.events, [])
    }

    func testAMalletHitEmitsOneEventWithItsClosingSpeed() {
        var r = rink()
        let reach = r.table.puckRadius + r.table.malletRadius
        // Just inside reach, then shoved further into the puck.
        r.placeMallet(of: bottom, at: r.table.center + Vec2(0, reach - 0.5))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, -3))])
        let hits = r.events.filter { if case .malletHit = $0 { return true } else { return false } }
        XCTAssertEqual(hits.count, 1)
        guard case .malletHit(let player, let speed) = hits.first else {
            return XCTFail("expected exactly one mallet-hit event, got \(r.events)")
        }
        XCTAssertEqual(player, bottom)
        XCTAssertGreaterThan(speed, 0)
    }

    func testARestingMalletThePuckDriftsIntoIsNotAHit() {
        var r = rink()
        let m = r.mallet(of: bottom).position
        r.place(Puck(position: m - Vec2(0, 20), velocity: Vec2(0, 200)))
        var mallletHits = 0
        for _ in 0..<Rink.tickRate {
            r.advance(inputs: [:])  // the mallet never moves
            mallletHits +=
                r.events.filter { if case .malletHit = $0 { return true } else { return false } }
                .count
        }
        XCTAssertEqual(
            mallletHits, 0, "a moving puck hitting a still mallet is a bounce, not a strike")
    }

    func testAWallBounceEmitsItsSpeed() {
        var r = rink()
        r.place(Puck(position: Vec2(r.table.puckField.maxX - 1, 80), velocity: Vec2(200, 0)))
        var speed: Double?
        for _ in 0..<Rink.tickRate {
            r.advance(inputs: [:])
            for event in r.events {
                if case .wallBounce(let s) = event { speed = s }
            }
            if speed != nil { break }
        }
        XCTAssertNotNil(speed)
        XCTAssertGreaterThan(speed ?? 0, 0)
    }

    func testAGoalEmitsGoalThenGameOverOnTheWinningStrike() {
        var r = rink(rules: Rules(pointsToWin: 1))
        r.place(
            Puck(
                position: Vec2(r.table.center.x, r.table.puckField.minY + 1),
                velocity: Vec2(0, -300)))
        r.advance(inputs: [:])
        XCTAssertEqual(r.events, [.goal(scorer: bottom, conceder: top), .gameOver(winner: bottom)])
    }

    func testANonWinningGoalEmitsNoGameOver() {
        var r = rink(rules: Rules(pointsToWin: 5))
        r.place(
            Puck(
                position: Vec2(r.table.center.x, r.table.puckField.minY + 1),
                velocity: Vec2(0, -300)))
        r.advance(inputs: [:])
        XCTAssertEqual(r.events, [.goal(scorer: bottom, conceder: top)])
    }

    func testEventsAreDeterministic() {
        func run() -> [[GameEvent]] {
            var r = Rink(table: .duel, lineup: .duel, seed: 7)
            var trail: [[GameEvent]] = []
            for tick in 0..<600 {
                let drag = Vec2(sin(Double(tick) / 9) * 4, cos(Double(tick) / 7) * 4)
                r.advance(inputs: [
                    bottom: SeatInput(malletDrag: drag), top: SeatInput(malletDrag: -drag),
                ])
                trail.append(r.events)
            }
            return trail
        }
        XCTAssertEqual(run(), run())
    }
}
