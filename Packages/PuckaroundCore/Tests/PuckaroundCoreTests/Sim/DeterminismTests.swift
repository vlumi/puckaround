import XCTest

@testable import PuckaroundCore

/// The sim's foundational promise: same seed + same inputs → same states,
/// bit-for-bit. Replays stand on this.
final class DeterminismTests: XCTestCase {
    private func scripted(player: PlayerID, tick: Tick, in rink: Rink) -> SeatInput {
        // Every seat swipes through the puck now and then, at a tick-dependent angle.
        guard (tick + player.rawValue * 7) % 23 == 0 else { return .none }
        let angle = Double(tick % 360) * .pi / 180 + Double(player.rawValue)
        let c = rink.puck.position
        return SeatInput(
            swipe: Swipe(
                from: c - Vec2(angle: angle) * 5, to: c + Vec2(angle: angle) * 5,
                velocity: Vec2(angle: angle) * 150))
    }

    private func run(seed: UInt64, ticks: Int) -> (rink: Rink, trail: [Vec2]) {
        let lineup = Lineup(playerCount: 4)!
        var rink = Rink(table: .standard(for: lineup), lineup: lineup, seed: seed)
        var trail: [Vec2] = []
        for _ in 0..<ticks {
            var inputs: [PlayerID: SeatInput] = [:]
            for player in lineup.players {
                inputs[player] = scripted(player: player, tick: rink.tick, in: rink)
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
    }

    func testTheSeedDecidesTheServe() {
        let a = Rink(table: .duel, lineup: .duel, seed: 1)
        let b = Rink(table: .duel, lineup: .duel, seed: 2)
        XCTAssertNotEqual(a.puck.velocity, b.puck.velocity)
    }

    func testServeIsReproducibleFromTheSeed() {
        var a = Rink(table: .duel, lineup: .duel, seed: 5)
        var b = Rink(table: .duel, lineup: .duel, seed: 5)
        a.serve()
        b.serve()
        XCTAssertEqual(a, b)
    }
}
