import XCTest

@testable import PuckaroundCore

/// The `GameEvent` stream the sound and haptics consume — a pure function of
/// the sim, so these run headless.
final class EventTests: XCTestCase {
    private let bottom = MalletSlot.bottomSingle
    private let top = MalletSlot.topSingle

    private func rink(rules: Rules = .standard) -> Rink {
        var r = Rink(table: .duel, rules: rules, seed: 1)
        r.startPlaying()
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
        r.placeMallet(at: bottom, position: r.table.center + Vec2(0, reach - 0.5))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, -3))])
        let hits = r.events.filter { if case .malletHit = $0 { return true } else { return false } }
        XCTAssertEqual(hits.count, 1)
        guard case .malletHit(let slot, let speed) = hits.first else {
            return XCTFail("expected exactly one mallet-hit event, got \(r.events)")
        }
        XCTAssertEqual(slot, bottom)
        XCTAssertGreaterThan(speed, 0)
    }

    func testARestingMalletThePuckDriftsIntoIsNotAHit() {
        var r = rink()
        let m = r.mallet(at: bottom)!.position
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
        // The goal fires on the tick the WHOLE puck clears the line. (Skip the
        // GO announced on play's first tick.)
        var goalEvents: [GameEvent] = []
        for _ in 0..<6
        where !goalEvents.contains(where: {
            if case .goal = $0 { return true } else { return false }
        }) {
            r.advance(inputs: [:])
            goalEvents = r.events.filter { $0 != .faceoffCleared }
        }
        XCTAssertEqual(
            goalEvents, [.goal(scorer: .bottom, conceder: .top), .gameOver(winner: .bottom)])
    }

    func testANonWinningGoalEmitsNoGameOver() {
        var r = rink(rules: Rules(pointsToWin: 5))
        r.place(
            Puck(
                position: Vec2(r.table.center.x, r.table.puckField.minY + 1),
                velocity: Vec2(0, -300)))
        var goalEvents: [GameEvent] = []
        for _ in 0..<6
        where !goalEvents.contains(where: {
            if case .goal = $0 { return true } else { return false }
        }) {
            r.advance(inputs: [:])
            goalEvents = r.events.filter { $0 != .faceoffCleared }
        }
        XCTAssertEqual(goalEvents, [.goal(scorer: .bottom, conceder: .top)])
    }

    func testEventsAreDeterministic() {
        func run() -> [[GameEvent]] {
            var r = Rink(table: .duel, seed: 7)
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

    func testTheFaceoffClearingEmitsAGo() {
        var r = Rink(table: .duel, seed: 1)
        r.park()
        r.ready(bottom)
        r.advance(inputs: [:])
        XCTAssertFalse(r.events.contains(.faceoffCleared), "one slot readied is not GO")
        r.ready(top)  // clears the faceoff → play begins
        XCTAssertTrue(r.isFaceoff == false)
        r.advance(inputs: [:])
        XCTAssertTrue(r.events.contains(.faceoffCleared), "the first tick of play announces GO")
        r.advance(inputs: [:])
        XCTAssertFalse(r.events.contains(.faceoffCleared), "and only that one tick")
    }
}
