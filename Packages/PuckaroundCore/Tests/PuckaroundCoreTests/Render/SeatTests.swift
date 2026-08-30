import SwiftUI
import XCTest

@testable import PuckaroundCore
@testable import PuckaroundKit

/// Which way labels read for each board turn: head-to-head upright and upside
/// down, both facing the bottom bench in landscape.
final class SeatTests: XCTestCase {
    func testPortraitIsHeadToHead() {
        XCTAssertEqual(Seat(side: .bottom).labelAngle.degrees, 0, accuracy: 1e-9)
        XCTAssertEqual(Seat(side: .top).labelAngle.degrees, 180, accuracy: 1e-9)
    }

    func testLandscapeCancelsTheQuarterTurnForBothSides() {
        for turn in [90.0, -90.0] {
            for side in Side.allCases {
                let seat = Seat(side: side, boardTurn: .degrees(turn))
                XCTAssertEqual(seat.labelAngle.degrees, -turn, accuracy: 1e-9)
            }
        }
    }

    /// The 180° flip already puts each player's end at their physical side, so
    /// the labels keep the head-to-head layout rather than counter-turning.
    func testUpsideDownKeepsHeadToHead() {
        XCTAssertEqual(
            Seat(side: .bottom, boardTurn: .degrees(180)).labelAngle.degrees, 0, accuracy: 1e-9)
        XCTAssertEqual(
            Seat(side: .top, boardTurn: .degrees(180)).labelAngle.degrees, 180, accuracy: 1e-9)
    }
}
