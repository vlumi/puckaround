import XCTest

@testable import PuckaroundCore
@testable import PuckaroundKit

final class FitTests: XCTestCase {
    /// A portrait board on a portrait phone: no turn, width-bound, centered.
    func testPortraitBoardOnAPhoneIsWidthBound() {
        let p = BoardPlacement(
            board: Vec2(100, 160), screen: CGSize(width: 390, height: 844), margin: 12)
        XCTAssertFalse(p.landscape)
        XCTAssertEqual(p.turn.degrees, 0, accuracy: 1e-9)
        XCTAssertEqual(p.scale, 3.66, accuracy: 1e-9)  // (390-24)/100
        // The board's corners land centered: width 366, height 585.6.
        XCTAssertEqual(p.point(Vec2(0, 0)).x, 195 - 183, accuracy: 1e-6)
        XCTAssertEqual(p.point(Vec2(100, 160)).x, 195 + 183, accuracy: 1e-6)
    }

    /// A portrait board on a landscape screen: a quarter turn, and now the board's
    /// height is bound by the screen height (it fills, no side bars).
    func testPortraitBoardOnLandscapeTurnsAndFillsHeight() {
        let p = BoardPlacement(
            board: Vec2(100, 160), screen: CGSize(width: 844, height: 390), margin: 12)
        XCTAssertTrue(p.landscape)
        XCTAssertEqual(abs(p.turn.degrees), 90, accuracy: 1e-9)
        // Turned, the board's long side (160) spans the screen width (844) and its
        // short side (100) the height (390): height-bound at (390-24)/100 = 3.66.
        XCTAssertEqual(p.scale, 3.66, accuracy: 1e-9)
    }

    /// The whole point of one placement: a screen point maps back to the world
    /// point drawn there, in either orientation — so touches match the picture.
    func testPointAndWorldRoundTrip() {
        for screen in [CGSize(width: 390, height: 844), CGSize(width: 844, height: 390)] {
            let p = BoardPlacement(board: Vec2(100, 160), screen: screen)
            for world in [Vec2(0, 0), Vec2(100, 160), Vec2(50, 80), Vec2(12, 140)] {
                let back = p.world(fromScreen: p.point(world))
                XCTAssertEqual(back.x, world.x, accuracy: 1e-6)
                XCTAssertEqual(back.y, world.y, accuracy: 1e-6)
            }
        }
    }

    func testADegenerateScreenGivesNoScale() {
        let p = BoardPlacement(board: Vec2(100, 160), screen: .zero)
        XCTAssertEqual(p.scale, 0, accuracy: 1e-9)
    }
}
