import XCTest

@testable import PuckaroundCore

/// The survival feeder: pucks keep coming, the pace keeps climbing, and a
/// drain thins the pack instead of re-serving.
final class SurvivalTests: XCTestCase {
    /// Serve speed zero, so fed pucks pile near center instead of drifting
    /// into a goal mid-test — the feeder's bookkeeping stays observable.
    private var table: Playfield {
        var t = Playfield.duel
        t.serveSpeed = 0
        t.feed = PuckFeed(every: 1, cap: 3, shapes: [.circle, .square], ramp: 0.6)
        return t
    }

    private func playingRink(on table: Playfield) -> Rink {
        var r = Rink(table: table, rules: Rules(pointsToWin: 1_000_000, serveTo: .bottom), seed: 1)
        for slot in r.slots { r.ready(slot) }
        r.advance(inputs: [:])
        return r
    }

    /// Every `every` seconds one more puck beams in, cycling the shapes, and
    /// the feeder stops at its cap.
    func testTheFeederDealsToTheCap() {
        var r = playingRink(on: table)
        XCTAssertEqual(r.pucks.count, 1, "the faceoff puck alone")
        for _ in 0..<70 { r.advance(inputs: [:]) }
        XCTAssertEqual(r.pucks.count, 2, "one dealt after a second")
        XCTAssertEqual(r.pucks[1].shape, .circle, "the cycle starts at its first shape")
        for _ in 0..<60 { r.advance(inputs: [:]) }
        XCTAssertEqual(r.pucks.count, 3)
        XCTAssertEqual(r.pucks[2].shape, .square, "the cycle moved on")
        for _ in 0..<180 { r.advance(inputs: [:]) }
        XCTAssertEqual(r.pucks.count, 3, "capped — the table only holds so much chaos")
    }

    /// The clock alone ramps the pace on a feeder table.
    func testThePaceClimbsWithTheClock() {
        var r = playingRink(on: table)
        let early = r.pace
        for _ in 0..<120 { r.advance(inputs: [:]) }
        XCTAssertGreaterThan(r.pace, early)
        XCTAssertGreaterThan(r.pace, 2, "0.6 a second for two seconds")
    }

    /// A drain removes the puck — no re-serve — and an emptied table is
    /// restocked immediately, beam and all.
    func testADrainThinsThePackAndTheFeederRestocks() {
        var r = playingRink(on: table)
        r.setPuckForTesting(
            Puck(position: Vec2(50, r.table.puckField.maxY - 1), velocity: Vec2(0, 300)))
        var drained = false
        for _ in 0..<60 where !drained {
            r.advance(inputs: [:])
            drained = r.events.contains {
                if case .goal(_, let conceder) = $0 { return conceder == .bottom }
                return false
            }
        }
        XCTAssertTrue(drained)
        XCTAssertEqual(r.pucks.count, 1, "the table went empty and restocked at once")
        XCTAssertEqual(r.pucks[0].position, r.table.center)
        XCTAssertTrue(
            r.events.contains { if case .puckBeamed = $0 { return true } else { return false } },
            "the restock beams in")
    }

    /// Same seed, same inputs, feeder and all — bit-identical.
    func testASurvivalTableIsDeterministic() {
        func run() -> Rink {
            var r = playingRink(on: table)
            r.setPuckForTesting(Puck(position: Vec2(40, 100), velocity: Vec2(30, -80)))
            for _ in 0..<240 { r.advance(inputs: [:]) }
            return r
        }
        XCTAssertEqual(run(), run())
    }
}
