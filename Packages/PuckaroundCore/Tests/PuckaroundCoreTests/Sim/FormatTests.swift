import XCTest

@testable import PuckaroundCore

/// The new slot/side machinery the refactor introduced: how a format lays out
/// its mallet slots, how each side's goal widens with its hand count, and how a
/// doubles side splits its half into two lanes.
final class FormatTests: XCTestCase {
    func testOneVsOneHasBothFullLanes() {
        let slots = Format.oneVsOne.slots
        XCTAssertEqual(slots, [.bottomSingle, .topSingle])
    }

    func testOneVsTwoSplitsOnlyTheTwoHandSide() {
        let slots = Format.oneVsTwo.slots
        // Bottom's one full lane, then top's two — bottom lanes always first.
        XCTAssertEqual(
            slots,
            [
                MalletSlot(side: .bottom, lane: .full),
                MalletSlot(side: .top, lane: .left),
                MalletSlot(side: .top, lane: .right),
            ])
    }

    func testTwoVsTwoHasFourLanesBottomFirst() {
        let slots = Format.twoVsTwo.slots
        XCTAssertEqual(slots.count, 4)
        XCTAssertEqual(
            slots,
            [
                MalletSlot(side: .bottom, lane: .left),
                MalletSlot(side: .bottom, lane: .right),
                MalletSlot(side: .top, lane: .left),
                MalletSlot(side: .top, lane: .right),
            ])
    }

    func testTheTwoHandSideGetsTheWiderGoal() {
        let table = Playfield.duel.with(format: .oneVsTwo)
        // Bottom fields one hand → narrow goal; top fields two → the doubles width.
        XCTAssertEqual(table.goalWidth(for: .bottom), table.goalWidth)
        XCTAssertEqual(table.goalWidth(for: .top), table.doublesGoalWidth)
    }

    func testDoublesLanesAreDisjointAndMeetAtCenter() {
        let table = Playfield.duel.with(format: .twoVsTwo)
        let left = table.malletZone(for: MalletSlot(side: .bottom, lane: .left))
        let right = table.malletZone(for: MalletSlot(side: .bottom, lane: .right))
        let r = table.malletRadius
        // Left runs from the outer wall inset to center-x; right from center-x to
        // its outer wall inset — they meet at center-x and never overlap.
        XCTAssertEqual(left.minX, r, "left inset from the left wall")
        XCTAssertEqual(left.maxX, table.size.x / 2, "left reaches the center line")
        XCTAssertEqual(right.minX, table.size.x / 2, "right starts at the center line")
        XCTAssertEqual(right.maxX, table.size.x - r, "right inset from the right wall")
        XCTAssertLessThanOrEqual(left.maxX, right.minX, "the lanes are disjoint")
    }

    func testAFullLaneSpansTheWholeHalf() {
        let table = Playfield.duel
        let full = table.malletZone(for: .bottomSingle)
        let r = table.malletRadius
        XCTAssertEqual(full.minX, r)
        XCTAssertEqual(full.width, table.size.x - 2 * r, "the full half, inset both walls")
    }
}
