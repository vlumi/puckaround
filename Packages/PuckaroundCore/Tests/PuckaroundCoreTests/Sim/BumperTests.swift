import XCTest

@testable import PuckaroundCore

/// Bumpers and the solo table they debut on: an empty machine end, one human
/// mallet, and pinball furniture that kicks.
final class BumperTests: XCTestCase {
    private var table: Playfield {
        var t = Playfield.duel.with(format: .solo)
        t.bumpers = [Bumper(position: Vec2(50, 40), radius: 6, kick: 60)]
        return t
    }

    private func playingRink() -> Rink {
        var r = Rink(table: table, rules: Rules(pointsToWin: 1_000_000, serveTo: .bottom), seed: 1)
        for slot in r.slots { r.ready(slot) }
        r.advance(inputs: [:])
        return r
    }

    /// A solo format fields one mallet, and the machine's empty half owns no
    /// touches at all.
    func testASoloTableFieldsOneMallet() {
        XCTAssertEqual(Format.solo.slots, [MalletSlot(side: .bottom, lane: .full)])
        let zones = SeatZones(format: .solo, bounds: Playfield.duel.bounds)
        XCTAssertNil(zones.owner(of: Vec2(50, 10)), "nobody home up top")
        XCTAssertEqual(zones.owner(of: Vec2(50, 150)), MalletSlot(side: .bottom, lane: .full))
    }

    /// With one slot on the table, one ready is everyone: play begins.
    func testTheLoneMalletStartsPlayAlone() {
        var r = Rink(table: table, seed: 1)
        XCTAssertTrue(r.isFaceoff)
        r.ready(MalletSlot(side: .bottom, lane: .full))
        XCTAssertFalse(r.isFaceoff)
    }

    /// A puck driven into a bumper clangs, bounces back, and leaves faster
    /// than the bounce alone would send it — the kick.
    func testABumperKicksThePuckBackFaster() {
        var r = playingRink()
        r.setPuckForTesting(Puck(position: Vec2(50, 60), velocity: Vec2(0, -100)))
        var clanged = false
        for _ in 0..<120 where !clanged {
            r.advance(inputs: [:])
            clanged = r.events.contains {
                if case .bumperHit = $0 { return true } else { return false }
            }
        }
        XCTAssertTrue(clanged, "the puck reached the bumper")
        XCTAssertGreaterThan(r.puck.velocity.y, 0, "bounced back the way it came")
        XCTAssertGreaterThan(
            r.puck.velocity.length, 100 * r.table.restitution,
            "faster than the bounce alone — the kick added speed")
    }

    /// A puck resting against a bumper is pushed clear but never kicked — no
    /// closing speed means no clang and no free points; being dead in the
    /// empty half, it then quietly re-serves (see the rescue test).
    func testARestingPuckIsNotMachineGunned() {
        var r = playingRink()
        r.setPuckForTesting(Puck(position: Vec2(50, 49.5), velocity: .zero))
        r.advance(inputs: [:])
        XCTAssertFalse(
            r.events.contains { if case .bumperHit = $0 { return true } else { return false } })
        XCTAssertEqual(r.puck.position, r.table.center, "dead in the empty half — re-served")
    }

    /// A doomed puck doesn't wait to stop: past the reach line and too slow
    /// for its remaining travel to reach the line, the goal or a bumper, it
    /// beams out mid-drift.
    func testADoomedPuckBeamsOutEarly() {
        var r = playingRink()
        r.setPuckForTesting(Puck(position: Vec2(20, 40), velocity: Vec2(0, -5)))
        r.advance(inputs: [:])
        XCTAssertTrue(
            r.events.contains { if case .puckBeamed = $0 { return true } else { return false } })
        XCTAssertEqual(r.puck.position, r.table.center)
    }

    /// Still fast enough that something could yet happen: left to play.
    func testAFastPuckIsLeftToPlay() {
        var r = playingRink()
        r.setPuckForTesting(Puck(position: Vec2(20, 40), velocity: Vec2(0, -100)))
        r.advance(inputs: [:])
        XCTAssertFalse(
            r.events.contains { if case .puckBeamed = $0 { return true } else { return false } })
    }

    /// A puck that dies where nobody can reach it re-serves to the player —
    /// no foul, no lost life; one dead in the player's own half stays put.
    func testADeadPuckInTheEmptyHalfReServes() {
        var r = playingRink()
        r.setPuckForTesting(Puck(position: Vec2(20, 40), velocity: .zero))
        r.advance(inputs: [:])
        XCTAssertEqual(r.puck.position, r.table.center, "warped to center")
        XCTAssertGreaterThan(r.puck.velocity.y, 0, "gliding back to the player")
        // In reach it is the player's problem: a dead puck down low stays.
        r.setPuckForTesting(Puck(position: Vec2(20, 120), velocity: .zero))
        r.advance(inputs: [:])
        XCTAssertEqual(r.puck.position, Vec2(20, 120), "the player's half is theirs to clear")
    }

    /// Same seed, same inputs, bumpers and all — bit-identical.
    func testABumperTableIsDeterministic() {
        func run() -> Rink {
            var r = playingRink()
            r.setPuckForTesting(Puck(position: Vec2(48, 60), velocity: Vec2(15, -140)))
            for _ in 0..<180 { r.advance(inputs: [:]) }
            return r
        }
        XCTAssertEqual(run(), run())
    }
}
