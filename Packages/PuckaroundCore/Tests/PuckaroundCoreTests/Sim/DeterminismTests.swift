import XCTest

@testable import PuckaroundCore

/// The sim's foundational promise: same seed + same inputs → same states,
/// bit-for-bit. Replays stand on this.
final class DeterminismTests: XCTestCase {
    /// Both hands waving their mallets about in tick-dependent loops. The two
    /// singles slots differ by side, so each gets its own phase offset (bottom
    /// 0, top 1) — the way the old two players did.
    private func scripted(slot: MalletSlot, tick: Tick) -> SeatInput {
        let phase = Double(tick) / 17 + (slot.side == .bottom ? 0 : 1) * 2
        return SeatInput(malletDrag: Vec2(sin(phase) * 3, cos(phase * 1.3) * 3))
    }

    private func run(seed: UInt64, ticks: Int) -> (rink: Rink, trail: [Vec2]) {
        var rink = Rink(table: .duel, seed: seed)
        rink.startPlaying()
        var trail: [Vec2] = []
        for _ in 0..<ticks {
            var inputs: [MalletSlot: SeatInput] = [:]
            for slot in rink.slots {
                inputs[slot] = scripted(slot: slot, tick: rink.tick)
            }
            rink.advance(inputs: inputs)
            trail.append(rink.puck.position)
        }
        return (rink, trail)
    }

    func testIdenticalRunsProduceIdenticalStates() {
        let a = run(seed: 42, ticks: 1800)
        let b = run(seed: 42, ticks: 1800)
        // Report the first diverging TICK, not just that the end states differ.
        if let tick = Array(zip(a.trail, b.trail)).firstIndex(where: { $0 != $1 }) {
            XCTFail("runs diverged at tick \(tick) of 1800")
        }
        XCTAssertEqual(a.rink, b.rink)
        XCTAssertEqual(a.rink.tick, 1800)
        // The script actually moved the puck at some point (it may end back at
        // center after a goal, so compare against the whole trail, not just last).
        XCTAssertTrue(a.trail.contains { $0 != a.trail.first }, "the script moved the puck")
    }

    func testEveryGameOpensTheSameWay() {
        // No chance in the opening now — a faceoff, puck frozen at center — so
        // the seed does not change how a game begins.
        let a = Rink(table: .duel, seed: 1)
        let b = Rink(table: .duel, seed: 999)
        XCTAssertTrue(a.isFaceoff)
        XCTAssertEqual(a.puck.position, a.table.center)
        XCTAssertEqual(a.puck.position, b.puck.position)
        XCTAssertFalse(a.puck.isMoving)
    }

    func testNewGameIsReproducibleFromTheSeed() {
        var a = Rink(table: .duel, seed: 5)
        var b = Rink(table: .duel, seed: 5)
        a.newMatch()
        b.newMatch()
        XCTAssertEqual(a, b)
    }
}
