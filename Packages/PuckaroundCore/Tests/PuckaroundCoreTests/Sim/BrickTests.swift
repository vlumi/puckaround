import XCTest

@testable import PuckaroundCore

/// The breakout wall: bricks smash, grazes don't, and a goal racks it fresh.
final class BrickTests: XCTestCase {
    /// One brick off to the left — clear of the goal mouth, so a shot can
    /// score without touching it.
    private var table: Playfield {
        var t = Playfield.duel.with(format: .solo)
        t.stages = [TableStage(bricks: [Brick(rect: Rect(x: 4, y: 12, width: 12, height: 6))])]
        return t
    }

    /// Drive a fresh puck through the mouth until a goal lands.
    private func scoreThroughTheMouth(_ r: inout Rink) {
        r.setPuckForTesting(
            Puck(position: Vec2(50, r.table.puckField.minY + 1), velocity: Vec2(0, -300)))
        for _ in 0..<60 {
            r.advance(inputs: [:])
            if r.events.contains(where: {
                if case .goal = $0 { return true } else { return false }
            }) {
                return
            }
        }
        XCTFail("never scored")
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

    /// A slow puck CLOSE to a brick isn't beamed — it can still reach and
    /// smash it, so its fate isn't sealed and the rescue keeps its hands off.
    func testASlowPuckNearABrickIsNotBeamed() {
        var r = playingRink(on: table)
        r.setPuckForTesting(Puck(position: Vec2(10, 24), velocity: Vec2(0, -12)))
        r.advance(inputs: [:])
        XCTAssertFalse(
            r.events.contains { if case .puckBeamed = $0 { return true } else { return false } })
        XCTAssertEqual(r.bricks.count, 1)
    }

    /// Every clear advances the stage; a drain replays it.
    func testTheWallLevelsUpOnClears() {
        var t = Playfield.duel.with(format: .solo)
        let brick = Brick(rect: Rect(x: 4, y: 12, width: 12, height: 6))
        let second = Brick(rect: Rect(x: 20, y: 12, width: 12, height: 6))
        t.stages = [TableStage(bricks: [brick]), TableStage(bricks: [brick, second])]
        var r = playingRink(on: t)
        // Score into the wall's half: the next rack is stage two — thicker.
        scoreThroughTheMouth(&r)
        XCTAssertEqual(r.bricks.count, 2, "cleared once — the wall came back thicker")
        // Drain the own goal: racks again, but failing isn't progress.
        r.setPuckForTesting(
            Puck(position: Vec2(50, r.table.puckField.maxY - 1), velocity: Vec2(0, 300)))
        for _ in 0..<60 where r.score(of: .top) < 1 { r.advance(inputs: [:]) }
        XCTAssertEqual(r.score(of: .top), 1, "the drain scored against the player")
        XCTAssertEqual(r.wallLevel, 1)
        XCTAssertEqual(r.bricks.count, 2, "a drain replays the stage")
    }

    /// Clearing the last stage loops to the first — with the pace turned up
    /// and that stage's own pucks in the air.
    func testTheStagesLoopFasterOnceCleared() {
        var t = Playfield.duel.with(format: .solo)
        let brick = Brick(rect: Rect(x: 4, y: 12, width: 12, height: 6))
        t.stages = [
            TableStage(bricks: [brick]),
            TableStage(bricks: [brick], pucks: [.circle, .circle]),
        ]
        var r = playingRink(on: t)
        XCTAssertEqual(r.pucks.count, 1, "the opening stage flies one puck")
        scoreThroughTheMouth(&r)
        XCTAssertEqual(r.pucks.count, 2, "the second stage flies two")
        XCTAssertEqual(r.pace, 1, "still the first lap")
        scoreThroughTheMouth(&r)
        XCTAssertEqual(r.pucks.count, 1, "one of the pair gone — the stage plays on")
        XCTAssertEqual(r.wallLevel, 1, "not resolved while a puck flies")
        scoreThroughTheMouth(&r)
        XCTAssertEqual(r.pucks.count, 1, "looped back to the first stage")
        XCTAssertEqual(r.wallLevel, 2)
        XCTAssertEqual(r.pace, 1.25, "the lap turned the pace up")
    }

    /// Multi-puck stages: a scored puck leaves and nothing respawns; the
    /// stage advances only once the last puck is gone.
    func testPucksDoNotRespawnMidStage() {
        var t = Playfield.duel.with(format: .solo)
        let brick = Brick(rect: Rect(x: 4, y: 12, width: 12, height: 6))
        t.stages = [
            TableStage(bricks: [brick], pucks: [.circle, .circle]),
            TableStage(bricks: [brick]),
        ]
        var r = playingRink(on: t)
        scoreThroughTheMouth(&r)
        XCTAssertEqual(r.pucks.count, 1, "one gone, one still flying — no respawn")
        XCTAssertEqual(r.wallLevel, 0, "the stage isn't over while a puck flies")
        scoreThroughTheMouth(&r)
        XCTAssertEqual(r.wallLevel, 1, "table empty and something scored: cleared")
        XCTAssertEqual(r.pucks.count, 1, "the next stage flies its own pucks")
    }

    /// A stage whose every puck drains fails: the run's life, same stage again.
    func testAFullyDrainedStageFailsAndReplays() {
        var r = playingRink(on: table)
        r.setPuckForTesting(
            Puck(position: Vec2(50, r.table.puckField.maxY - 1), velocity: Vec2(0, 300)))
        var failed = false
        for _ in 0..<60 where !failed {
            r.advance(inputs: [:])
            failed = r.events.contains {
                if case .stageFailed = $0 { return true } else { return false }
            }
        }
        XCTAssertTrue(failed, "everything drained — the stage failed")
        XCTAssertEqual(r.wallLevel, 0, "failing isn't progress")
        XCTAssertEqual(r.pucks.count, 1, "the same stage racks again")
        XCTAssertEqual(r.bricks.count, 1)
    }

    /// A sturdy brick chips before it breaks — each hit pays its event, and
    /// only the last removes it.
    func testASturdyBrickChipsThenBreaks() {
        var t = Playfield.duel.with(format: .solo)
        t.stages = [
            TableStage(bricks: [Brick(rect: Rect(x: 40, y: 20, width: 20, height: 6), hits: 2)])
        ]
        var r = playingRink(on: t)
        r.setPuckForTesting(Puck(position: Vec2(50, 40), velocity: Vec2(0, -160)))
        var chipped = false
        for _ in 0..<120 where !chipped {
            r.advance(inputs: [:])
            chipped = r.events.contains {
                if case .brickChipped = $0 { return true } else { return false }
            }
        }
        XCTAssertTrue(chipped, "the first hit chips")
        XCTAssertEqual(r.bricks.count, 1, "the wall held")
        XCTAssertEqual(r.bricks[0].hits, 1)
        r.setPuckForTesting(Puck(position: Vec2(50, 40), velocity: Vec2(0, -160)))
        var broke = false
        for _ in 0..<120 where !broke {
            r.advance(inputs: [:])
            broke = smashed(r)
        }
        XCTAssertTrue(broke, "the second hit breaks")
        XCTAssertTrue(r.bricks.isEmpty)
    }

    /// Same seed, same inputs, wall and all — bit-identical.
    func testABrickTableIsDeterministic() {
        var full = table
        full.stages = [
            TableStage(
                bricks: (0..<7).map {
                    Brick(rect: Rect(x: 8 + Double($0) * 12, y: 12, width: 12, height: 6), hits: 2)
                },
                pucks: [.circle, .square])
        ]
        func run() -> Rink {
            var r = playingRink(on: full)
            r.setPuckForTesting(Puck(position: Vec2(47, 60), velocity: Vec2(12, -180)))
            for _ in 0..<240 { r.advance(inputs: [:]) }
            return r
        }
        XCTAssertEqual(run(), run())
    }
}
