import XCTest

@testable import PuckaroundCore

/// A goal is scored against the side whose line the puck crosses — so a puck
/// driven into a side's OWN goal is the opponent's point, whoever last touched
/// it. There is no "who shot it", only which line it crossed.
final class OwnGoalTests: XCTestCase {
    private func rink() -> Rink {
        var r = Rink(table: .duel, rules: Rules(pointsToWin: 5), seed: 1)
        r.startPlaying()
        r.park()
        return r
    }

    func testCrossingYourOwnLineScoresForTheOpponent() {
        var r = rink()
        // Drive the puck fully through the BOTTOM goal — the bottom side's own
        // line. That is a goal against bottom, so the opponent (top) scores.
        let ownGoal = Side.bottom
        r.place(
            Puck(
                position: Vec2(r.table.center.x, r.table.puckField.maxY - 1),
                velocity: Vec2(0, 300)))
        let before = r.score(of: ownGoal.opponent)
        for _ in 0..<6 where r.score(of: ownGoal.opponent) == before { r.advance(inputs: [:]) }
        XCTAssertEqual(
            r.score(of: ownGoal.opponent), before + 1, "the opponent side takes the point")
        XCTAssertEqual(r.score(of: ownGoal), 0, "the conceding side scores nothing")
        XCTAssertTrue(
            r.events.contains(.goal(scorer: ownGoal.opponent, conceder: ownGoal)),
            "the goal names conceder and scorer as opposite sides")
    }
}
