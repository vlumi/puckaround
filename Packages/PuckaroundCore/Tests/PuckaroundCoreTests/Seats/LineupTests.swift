import XCTest

@testable import PuckaroundCore

final class LineupTests: XCTestCase {
    func testOnlyTwoToFourPlayersSeat() {
        XCTAssertNil(Lineup(playerCount: 1))
        XCTAssertNil(Lineup(playerCount: 5))
        for n in 2...4 {
            XCTAssertEqual(Lineup(playerCount: n)?.players.count, n)
        }
    }

    func testTeamsNeedExactlyFour() {
        XCTAssertNil(Lineup(playerCount: 2, teamed: true))
        XCTAssertNil(Lineup(playerCount: 3, teamed: true))
        XCTAssertNotNil(Lineup(playerCount: 4, teamed: true))
    }

    func testTwoPlayersFaceEachOther() {
        let duel = Lineup.duel
        XCTAssertEqual(duel.seat(of: PlayerID(0)), .bottom)
        XCTAssertEqual(duel.seat(of: PlayerID(1)), .top)
        XCTAssertEqual(duel.seat(of: PlayerID(0)).inward, -duel.seat(of: PlayerID(1)).inward)
    }

    func testEverySeatIsADistinctEdge() {
        let four = Lineup(playerCount: 4)!
        XCTAssertEqual(Set(four.players.map(four.seat(of:))).count, 4)
        XCTAssertTrue(four.contains(PlayerID(3)))
        XCTAssertFalse(four.contains(PlayerID(4)))
    }

    func testPartnersSitAcrossFromEachOther() {
        let teams = Lineup(playerCount: 4, teamed: true)!
        XCTAssertEqual(teams.team(of: PlayerID(0)), 0)
        XCTAssertEqual(teams.team(of: PlayerID(1)), 0)
        XCTAssertEqual(teams.team(of: PlayerID(2)), 1)
        XCTAssertEqual(teams.team(of: PlayerID(3)), 1)
        XCTAssertTrue(teams.areAllies(PlayerID(0), PlayerID(1)))
        XCTAssertFalse(teams.areAllies(PlayerID(0), PlayerID(2)))
        // Partners face each other: bottom + top.
        XCTAssertEqual(teams.seat(of: PlayerID(0)).inward, -teams.seat(of: PlayerID(1)).inward)
    }

    func testFreeForAllHasNoAlliesButOneself() {
        let four = Lineup(playerCount: 4)!
        XCTAssertNil(four.team(of: PlayerID(0)))
        XCTAssertTrue(four.areAllies(PlayerID(2), PlayerID(2)))
        XCTAssertFalse(four.areAllies(PlayerID(0), PlayerID(1)))
    }
}
