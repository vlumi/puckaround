import XCTest

@testable import PuckaroundCore

/// The breakout wall: bricks smash, grazes don't, and a goal racks it fresh.
final class BrickTests: XCTestCase {
    /// One brick off to the left — clear of the goal mouth, so a shot can
    /// score without touching it.
    private var table: Playfield {
        var t = Playfield.duel.with(format: .solo)
        t.bricks = [Brick(rect: Rect(x: 4, y: 12, width: 12, height: 6))]
        return t
    }

    private func playingRink(on table: Playfield) -> Rink {
        var r = Rink(table: table, rules: Rules(pointsToWin: 1_000_000, serveTo: .bottom), seed: 1)
        for slot in r.slots { r.ready(slot) }
        r.advance(inputs: [:])
        return r
    }

    private func smashed(_ rink: Rink) -> Bool {
        rink.events.contains { if case .brickBroken = $0 { return true } else { return false } }
    }

    /// A puck driven into a brick smashes it: the brick is gone, the puck
    /// bounces back, and the tick says so.
    func testAPuckSmashesThroughABrick() {
        var r = playingRink(on: table)
        r.setPuckForTesting(Puck(position: Vec2(10, 40), velocity: Vec2(0, -160)))
        var broke = false
        for _ in 0..<120 where !broke {
            r.advance(inputs: [:])
            broke = smashed(r)
        }
        XCTAssertTrue(broke, "the puck reached the wall")
        XCTAssertTrue(r.bricks.isEmpty, "the brick is gone")
        XCTAssertGreaterThan(r.puck.velocity.y, 0, "bounced off the face it hit")
    }

    /// A puck overlapping a brick while moving AWAY is pushed clear without
    /// breaking anything — no free points off a graze.
    func testAGrazeAwayBreaksNothing() {
        var r = playingRink(on: table)
        r.setPuckForTesting(Puck(position: Vec2(10, 19), velocity: Vec2(0, 60)))
        r.advance(inputs: [:])
        XCTAssertFalse(smashed(r))
        XCTAssertEqual(r.bricks.count, 1, "the brick survives")
        XCTAssertGreaterThanOrEqual(r.puck.position.y, 22, "pushed clear below the wall")
    }

    /// A goal racks the wall fresh — the next point is defended like the first.
    func testAGoalRacksTheWallFresh() {
        var r = playingRink(on: table)
        // Smash the lone brick first...
        r.setPuckForTesting(Puck(position: Vec2(10, 40), velocity: Vec2(0, -160)))
        for _ in 0..<120 where !r.bricks.isEmpty { r.advance(inputs: [:]) }
        XCTAssertTrue(r.bricks.isEmpty)
        // ...then score through the (clear) mouth.
        let y = r.table.puckField.minY + 1
        r.setPuckForTesting(Puck(position: Vec2(50, y), velocity: Vec2(0, -300)))
        var scored = false
        for _ in 0..<60 where !scored {
            r.advance(inputs: [:])
            scored = r.events.contains { if case .goal = $0 { return true } else { return false } }
        }
        XCTAssertTrue(scored)
        XCTAssertEqual(r.bricks.count, 1, "the wall racked fresh")
    }

    /// Same seed, same inputs, wall and all — bit-identical.
    func testABrickTableIsDeterministic() {
        var full = table
        full.bricks = (0..<7).map {
            Brick(rect: Rect(x: 8 + Double($0) * 12, y: 12, width: 12, height: 6))
        }
        func run() -> Rink {
            var r = playingRink(on: full)
            r.setPuckForTesting(Puck(position: Vec2(47, 60), velocity: Vec2(12, -180)))
            for _ in 0..<240 { r.advance(inputs: [:]) }
            return r
        }
        XCTAssertEqual(run(), run())
    }
}
