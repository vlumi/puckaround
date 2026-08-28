import XCTest

@testable import PuckaroundCore

/// The reported trap: a puck resting against a wall that no mallet hit can
/// free, because a player naturally strikes ALONG the wall and the mallet can
/// never get between the puck and the wall to hit it inward.
///
/// The genuine failure was the puck left at REST on the wall line — zero
/// velocity, nowhere to go. The fix guarantees any mallet contact against a
/// wall ends with the puck carrying real speed (off the wall, or fast along it
/// so drag peels it away), never dead-stopped on the line.
final class WallStickTests: XCTestCase {
    private let bottom = PlayerID(0)

    private func rink() -> Rink {
        var r = Rink(table: .duel, lineup: .duel, seed: 1)
        r.startPlaying()
        r.park()
        return r
    }

    private func onLeftWall(_ r: Rink) -> Bool {
        r.puck.position.x <= r.table.puckField.minX + 0.01
    }

    /// The instinctive "scrape it off": mallet beside the wall-puck, sweeping
    /// down the wall. It used to do nothing; now it knocks the puck loose.
    func testAMalletStrokeDownTheWallFreesThePuck() {
        var r = rink()
        r.place(Puck(position: Vec2(r.table.puckField.minX, r.table.center.y + 30)))
        let reach = r.table.malletRadius + r.table.puckRadius
        r.placeMallet(of: bottom, at: r.puck.position + Vec2(reach - 1, -12))
        var freed = false
        for _ in 0..<8 {
            r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(0, 6))])
            if r.puck.position.x > r.table.puckField.minX + 1, r.puck.velocity.x > 1 {
                freed = true
            }
        }
        XCTAssertTrue(freed, "a stroke down the wall must knock the puck off it")
    }

    /// A mallet contact against the wall never leaves the puck at rest on the
    /// line — the pin. Any inward-ish shove frees it; a mallet that can only
    /// press it into the wall sends it sliding along at speed, which drag then
    /// peels off. Either way it is moving, never stuck.
    func testAContactNeverLeavesThePuckDeadOnTheWall() {
        for degrees in stride(from: 0, to: 360, by: 30) {
            var r = rink()
            r.place(Puck(position: Vec2(r.table.puckField.minX, r.table.center.y + 30)))
            let a = Double(degrees) * .pi / 180
            let reach = r.table.malletRadius + r.table.puckRadius
            r.placeMallet(of: bottom, at: r.puck.position + Vec2(cos(a), sin(a)) * (reach - 1))
            r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(cos(a), sin(a)) * -2)])
            XCTAssertFalse(
                onLeftWall(r) && r.puck.velocity.length < 1,
                "dead on the wall from angle \(degrees)")
        }
    }

    /// The same escape works on a HORIZONTAL wall — the puck slides along the
    /// bottom boards, not just the sides. (Placed off the goal mouth so a real
    /// escape, not a goal, is what frees it.)
    func testAContactFreesThePuckOffTheBottomWall() {
        var r = rink()
        let x = r.table.puckField.minX + 8  // clear of the centred goal mouth
        r.place(Puck(position: Vec2(x, r.table.puckField.maxY)))
        let reach = r.table.malletRadius + r.table.puckRadius
        r.placeMallet(of: bottom, at: Vec2(x + 10, r.table.puckField.maxY - reach + 1))
        var freed = false
        for _ in 0..<8 {
            r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(-4, 3))])
            if r.puck.position.y < r.table.puckField.maxY - 1, r.puck.velocity.y < -1 {
                freed = true
            }
        }
        XCTAssertTrue(freed, "a contact must knock the puck off the bottom wall too")
    }

    /// And it clears the wall within a beat when the mallet lets go — proving
    /// "moving along the wall" really does become "off the wall", not a
    /// permanent slide.
    func testAFreedPuckLeavesTheWallOnItsOwn() {
        var r = rink()
        r.place(Puck(position: Vec2(r.table.puckField.minX, r.table.center.y + 30)))
        // A shove straight at the wall from inward — the worst case, no along.
        let reach = r.table.malletRadius + r.table.puckRadius
        r.placeMallet(of: bottom, at: r.puck.position + Vec2(reach - 1, 0))
        r.advance(inputs: [bottom: SeatInput(malletDrag: Vec2(-3, 0))])
        // Mallet gone; let it coast.
        r.placeMallet(of: bottom, at: r.table.malletZone(for: .bottom).center)
        var left = false
        for _ in 0..<30 where !left {
            r.advance(inputs: [:])
            if r.puck.position.x > r.table.puckField.minX + r.table.puckRadius { left = true }
        }
        XCTAssertTrue(left, "the freed puck must come off the wall on its own")
    }
}
