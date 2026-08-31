import XCTest

@testable import PuckaroundCore

/// Several pucks at once: a deterministic row at the faceoff, continuous play
/// through goals, and puck-on-puck clacks — all in fixed index order.
final class MultiPuckTests: XCTestCase {
    private var table: Playfield {
        var t = Playfield.duel
        t.puckShapes = [.circle, .square, .triangle]
        return t
    }

    /// A three-puck rink already playing.
    private func rink(pointsToWin: Int = 7) -> Rink {
        var r = Rink(table: table, rules: Rules(pointsToWin: pointsToWin), seed: 1)
        for slot in r.slots { r.ready(slot) }
        r.advance(inputs: [:])
        return r
    }

    func testTheFaceoffSeatsARowOfPucks() {
        let r = Rink(table: table, seed: 1)
        XCTAssertEqual(r.pucks.count, 3)
        XCTAssertEqual(r.pucks.map(\.shape), [.circle, .square, .triangle])
        XCTAssertEqual(r.pucks[1].position, table.center, "the middle puck sits at center")
        XCTAssertEqual(r.pucks[0].position.y, r.pucks[2].position.y, "the row is level")
        XCTAssertLessThan(r.pucks[0].position.x, r.pucks[2].position.x)
    }

    /// A goal re-serves only the scored puck; the others keep flying.
    func testAGoalReservesTheScoredPuckWhileTheRestPlayOn() {
        var r = rink()
        let bystander = Puck(position: Vec2(20, 100), velocity: Vec2(50, 0))
        r.setPuckForTesting(bystander, at: 1)
        let y = r.table.puckField.minY + 1
        r.setPuckForTesting(
            Puck(position: Vec2(table.center.x, y), velocity: Vec2(0, -300)), at: 0)
        while !r.events.contains(where: { if case .goal = $0 { return true } else { return false } }
        ) {
            r.advance(inputs: [:])
        }
        XCTAssertEqual(r.score(of: .bottom), 1)
        XCTAssertEqual(r.phase, .playing, "the game rolls on")
        XCTAssertEqual(r.pucks[0].position, table.center, "the scored puck re-serves")
        XCTAssertLessThan(r.pucks[0].velocity.y, 0, "gliding into the conceder's half")
        XCTAssertEqual(r.pucks[0].shape, .circle, "a re-serve keeps the puck's shape")
        XCTAssertGreaterThan(r.pucks[1].velocity.x, 0, "the bystander keeps flying")
        XCTAssertNotEqual(r.pucks[1].position, bystander.position)
    }

    /// A game-winning goal freezes the table: every puck returns to the row.
    func testAWinningGoalParksEveryPuck() {
        var r = rink(pointsToWin: 1)
        r.setPuckForTesting(Puck(position: Vec2(20, 100), velocity: Vec2(50, 0)), at: 1)
        let y = r.table.puckField.minY + 1
        r.setPuckForTesting(
            Puck(position: Vec2(table.center.x, y), velocity: Vec2(0, -300)), at: 0)
        while r.phase == .playing { r.advance(inputs: [:]) }
        XCTAssertEqual(r.pucks, Rink.faceoffPucks(on: table))
    }

    /// Two pucks meeting head-on clack apart instead of overlapping.
    func testPucksClackOffEachOther() {
        var r = rink()
        r.setPuckForTesting(Puck(position: Vec2(40, 80), velocity: Vec2(60, 0)), at: 0)
        r.setPuckForTesting(Puck(position: Vec2(47, 80), velocity: Vec2(-60, 0)), at: 1)
        r.setPuckForTesting(Puck(position: Vec2(80, 140)), at: 2)
        r.advance(inputs: [:])
        XCTAssertTrue(
            r.events.contains { if case .puckHit = $0 { return true } else { return false } })
        XCTAssertLessThan(r.pucks[0].velocity.x, 0, "the left puck bounced back")
        XCTAssertGreaterThan(r.pucks[1].velocity.x, 0, "the right puck bounced away")
        let gap = r.pucks[0].position.distance(to: r.pucks[1].position)
        XCTAssertGreaterThanOrEqual(gap, table.puckRadius * 2 - 1e-9, "pushed clear")
    }

    /// Three pucks, same seed, same inputs — bit-identical states.
    func testAMultiPuckRunIsDeterministic() {
        func run() -> Rink {
            var r = rink()
            for _ in 0..<120 { r.advance(inputs: [:]) }
            return r
        }
        XCTAssertEqual(run(), run())
    }
}
