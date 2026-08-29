import XCTest

@testable import PuckaroundCore

/// The wrap-walls table variant: the long side walls are portals (exit one
/// side, enter the other) while the short goal walls stay solid.
final class WrapWallsTests: XCTestCase {
    private var wrapTable: Playfield {
        var t = Playfield.duel
        t.sideWalls = .wrap
        return t
    }

    private func rink(_ table: Playfield) -> Rink {
        var r = Rink(table: table, seed: 1)
        r.startPlaying()
        r.park()
        return r
    }

    func testTheDefaultTableIsSolid() {
        XCTAssertEqual(Playfield.duel.sideWalls, .solid)
    }

    func testAPuckExitsOneSideAndEntersTheOther() {
        var r = rink(wrapTable)
        // Fly left toward the left wall, along the mid-height so it never nears a goal.
        r.place(Puck(position: Vec2(6, 80), velocity: Vec2(-300, 0)))
        var wrapped = false
        for _ in 0..<Rink.tickRate {
            let xBefore = r.puck.position.x
            r.advance(inputs: [:])
            // A wrap is the only way x jumps from near 0 to near the far wall.
            if xBefore < 20, r.puck.position.x > 80 { wrapped = true; break }
        }
        XCTAssertTrue(wrapped, "the puck re-enters from the right")
        // Still travelling left (no reflection) — only drag has touched it, no bounce.
        XCTAssertLessThan(r.puck.velocity.x, 0, "kept its leftward direction — no bounce")
        XCTAssertEqual(r.puck.velocity.y, 0, accuracy: 1e-9, "and its straight line")
        XCTAssertEqual(r.puck.position.y, 80, accuracy: 1e-9, "at the same height")
    }

    func testASolidTableStillBouncesOffTheSide() {
        var r = rink(.duel)
        r.place(Puck(position: Vec2(6, 80), velocity: Vec2(-300, 0)))
        var bounced = false
        for _ in 0..<Rink.tickRate {
            r.advance(inputs: [:])
            if r.puck.velocity.x > 0 { bounced = true; break }
        }
        XCTAssertTrue(bounced, "a solid side wall reflects the puck back")
        XCTAssertTrue(r.table.puckField.insetBy(-1).contains(r.puck.position))
    }

    func testTheGoalWallsStillBounceOnAWrapTable() {
        var r = rink(wrapTable)
        // Straight up toward the top wall, off to the side of the goal mouth.
        r.place(Puck(position: Vec2(12, 80), velocity: Vec2(0, -300)))
        var bounced = false
        for _ in 0..<Rink.tickRate {
            r.advance(inputs: [:])
            if r.puck.velocity.y > 0 { bounced = true; break }
        }
        XCTAssertTrue(bounced, "the short goal walls stay solid when the sides wrap")
    }

    func testAGoalStillScoresOnAWrapTable() {
        var r = rink(wrapTable)
        r.place(
            Puck(position: Vec2(r.table.center.x, r.table.puckField.minY), velocity: Vec2(0, -300)))
        for _ in 0..<Rink.tickRate where r.score(of: .bottom) == 0 {
            r.advance(inputs: [:])
        }
        XCTAssertEqual(r.score(of: .bottom), 1, "bottom scores against the top goal")
    }

    func testAPolygonAlsoWraps() {
        var t = wrapTable
        t.puckShape = .square
        var r = rink(t)
        r.place(Puck(position: Vec2(6, 80), velocity: Vec2(-300, 0), angularVelocity: 4))
        var wrapped = false
        for _ in 0..<Rink.tickRate {
            let xBefore = r.puck.position.x
            r.advance(inputs: [:])
            if xBefore < 20, r.puck.position.x > 80 { wrapped = true; break }
        }
        XCTAssertTrue(wrapped, "a square puck wraps too")
    }

    func testAWrapRunIsDeterministic() {
        func run() -> Rink {
            var r = Rink(table: wrapTable, seed: 5)
            r.startPlaying()
            r.park()
            r.place(Puck(position: Vec2(30, 60), velocity: Vec2(-260, 40), angularVelocity: 3))
            for _ in 0..<1200 { r.advance(inputs: [:]) }
            return r
        }
        XCTAssertEqual(run(), run())
    }
}
