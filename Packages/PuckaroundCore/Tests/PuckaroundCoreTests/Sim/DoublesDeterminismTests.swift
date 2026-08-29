import XCTest

@testable import PuckaroundCore

/// Determinism holds with more than two mallets: a twoVsTwo table stepped from
/// the same seed with the same per-slot inputs lands bit-for-bit identical.
final class DoublesDeterminismTests: XCTestCase {
    /// Each of the four lanes waves in its own tick-dependent loop, so the four
    /// mallets never share a script.
    private func scripted(slot: MalletSlot, tick: Tick) -> SeatInput {
        let seed = (slot.side == .bottom ? 0.0 : 1.0) * 2 + (slot.lane == .left ? 0.0 : 1.0)
        let phase = Double(tick) / 13 + seed
        return SeatInput(malletDrag: Vec2(sin(phase) * 3, cos(phase * 1.1) * 3))
    }

    private func run(seed: UInt64, ticks: Int) -> Rink {
        var rink = Rink(table: Playfield.duel.with(format: .twoVsTwo), seed: seed)
        rink.startPlaying()
        for _ in 0..<ticks {
            var inputs: [MalletSlot: SeatInput] = [:]
            for slot in rink.slots {
                inputs[slot] = scripted(slot: slot, tick: rink.tick)
            }
            rink.advance(inputs: inputs)
        }
        return rink
    }

    func testIdenticalDoublesRunsProduceIdenticalStates() {
        let a = run(seed: 42, ticks: 1200)
        let b = run(seed: 42, ticks: 1200)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.slots.count, 4, "the run really exercised four mallets")
    }
}
