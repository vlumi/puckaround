import XCTest

@testable import PuckaroundCore

@MainActor
final class GameSessionTests: XCTestCase {
    private func session() -> GameSession {
        GameSession(rink: Rink(table: .duel, lineup: .duel, seed: 3)) { _, _ in .none }
    }

    func testFirstUpdateOnlyAnchorsTheClock() {
        let s = session()
        s.update(to: 100)
        XCTAssertEqual(s.rink.tick, 0)
    }

    func testTicksFollowElapsedTime() {
        let s = session()
        s.update(to: 100)
        s.update(to: 100 + Rink.dt * 3.5)
        XCTAssertEqual(s.rink.tick, 3)
        s.update(to: 100 + Rink.dt * 4.2)
        XCTAssertEqual(s.rink.tick, 4, "the half tick carried over")
    }

    func testALongHitchIsCappedAndForgotten() {
        let s = session()
        s.update(to: 0)
        s.update(to: 5)
        XCTAssertEqual(s.rink.tick, GameSession.maxTicksPerFrame)
        s.update(to: 5 + Rink.dt * 1.5)
        XCTAssertEqual(
            s.rink.tick, GameSession.maxTicksPerFrame + 1, "no catch-up debt survives the cap")
    }

    func testTimeGoingBackwardsOwesNothing() {
        let s = session()
        s.update(to: 10)
        s.update(to: 9)
        XCTAssertEqual(s.rink.tick, 0)
    }

    func testInputsAreGatheredPerSeatPerTick() {
        var asked: [(PlayerID, Tick)] = []
        let s = GameSession(rink: Rink(table: .duel, lineup: .duel, seed: 3)) { player, tick in
            asked.append((player, tick))
            return .none
        }
        s.advance()
        s.advance()
        XCTAssertEqual(asked.map(\.0), [PlayerID(0), PlayerID(1), PlayerID(0), PlayerID(1)])
        XCTAssertEqual(asked.map(\.1), [0, 0, 1, 1])
    }

    func testServeResetsThePuck() {
        let s = session()
        s.update(to: 0)
        s.update(to: 1)
        XCTAssertNotEqual(s.rink.puck.position, s.rink.table.center)
        s.serve()
        XCTAssertEqual(s.rink.puck.position, s.rink.table.center)
    }
}
