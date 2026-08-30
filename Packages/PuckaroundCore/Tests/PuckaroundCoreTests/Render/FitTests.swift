import XCTest

@testable import PuckaroundCore
@testable import PuckaroundKit

final class FitTests: XCTestCase {
    /// A portrait board on a portrait phone: no turn, width-bound, centered.
    func testPortraitBoardOnAPhoneIsWidthBound() {
        let p = BoardPlacement(
            board: Vec2(100, 160), screen: CGSize(width: 390, height: 844), margin: 12)
        XCTAssertEqual(p.turn.degrees, 0, accuracy: 1e-9)
        XCTAssertEqual(p.scale, 3.66, accuracy: 1e-9)  // (390-24)/100
        // The board's corners land centered: width 366, height 585.6.
        XCTAssertEqual(p.point(Vec2(0, 0)).x, 195 - 183, accuracy: 1e-6)
        XCTAssertEqual(p.point(Vec2(100, 160)).x, 195 + 183, accuracy: 1e-6)
    }

    /// Turned a quarter onto a landscape screen, the board's short side is bound
    /// by the screen height (it fills, no side bars) — either turn direction.
    func testQuarterTurnedBoardOnLandscapeFillsHeight() {
        for degrees in [90.0, -90.0] {
            let p = BoardPlacement(
                board: Vec2(100, 160), screen: CGSize(width: 844, height: 390),
                turnDegrees: degrees, margin: 12)
            XCTAssertEqual(p.turn.degrees, degrees, accuracy: 1e-9)
            // Turned, the board's long side (160) spans the screen width (844) and
            // its short side (100) the height: bound at (390-24)/100 = 3.66.
            XCTAssertEqual(p.scale, 3.66, accuracy: 1e-9)
        }
    }

    /// A half turn (upside-down phone) keeps the portrait fit — only flipped.
    func testHalfTurnKeepsThePortraitFit() {
        let p = BoardPlacement(
            board: Vec2(100, 160), screen: CGSize(width: 390, height: 844),
            turnDegrees: 180, margin: 12)
        XCTAssertEqual(p.scale, 3.66, accuracy: 1e-9)
        // The board's origin corner lands where its far corner sat unturned.
        XCTAssertEqual(p.point(Vec2(0, 0)).x, 195 + 183, accuracy: 1e-6)
    }

    /// The whole point of one placement: a screen point maps back to the world
    /// point drawn there, in every orientation — so touches match the picture.
    func testPointAndWorldRoundTrip() {
        let screens = [CGSize(width: 390, height: 844), CGSize(width: 844, height: 390)]
        for screen in screens {
            for degrees in [0.0, 90, -90, 180] {
                let p = BoardPlacement(
                    board: Vec2(100, 160), screen: screen, turnDegrees: degrees)
                for world in [Vec2(0, 0), Vec2(100, 160), Vec2(50, 80), Vec2(12, 140)] {
                    let back = p.world(fromScreen: p.point(world))
                    XCTAssertEqual(back.x, world.x, accuracy: 1e-6)
                    XCTAssertEqual(back.y, world.y, accuracy: 1e-6)
                }
            }
        }
    }

    func testADegenerateScreenGivesNoScale() {
        let p = BoardPlacement(board: Vec2(100, 160), screen: .zero)
        XCTAssertEqual(p.scale, 0, accuracy: 1e-9)
    }
}
