import XCTest

@testable import PuckaroundCore

@MainActor
final class GameSessionTests: XCTestCase {
    private func session() -> GameSession {
        GameSession(rink: Rink(table: .duel, seed: 3)) { _, _ in .none }
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

    func testInputsAreGatheredPerSlotPerTick() {
        var asked: [(MalletSlot, Tick)] = []
        let s = GameSession(rink: Rink(table: .duel, seed: 3)) { slot, tick in
            asked.append((slot, tick))
            return .none
        }
        s.advance()
        s.advance()
        XCTAssertEqual(asked.map(\.0), [.bottomSingle, .topSingle, .bottomSingle, .topSingle])
        XCTAssertEqual(asked.map(\.1), [0, 0, 1, 1])
    }

    func testNewGameStartsOver() {
        let s = session()
        s.update(to: 0)
        s.update(to: 1)
        XCTAssertGreaterThan(s.rink.tick, 0)
        let seedState = Rink(table: .duel, seed: 3)
        s.newGame()
        XCTAssertEqual(s.rink.score, [0, 0])
        XCTAssertEqual(
            s.rink.mallets, seedState.mallets, "nobody has moved, so the mallets are still home")
    }

    func testReadyForwardsToTheRinkAndStartsPlay() {
        let s = session()
        XCTAssertTrue(s.rink.isFaceoff, "a fresh session opens in a faceoff")
        s.ready(.bottomSingle)
        XCTAssertTrue(s.rink.isFaceoff, "one slot readied is not enough")
        s.ready(.topSingle)
        XCTAssertEqual(s.rink.phase, .playing, "both readied via the session → play begins")
    }
}
