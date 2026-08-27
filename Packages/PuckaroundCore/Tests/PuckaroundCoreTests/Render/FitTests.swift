import XCTest

@testable import PuckaroundCore
@testable import PuckaroundKit

final class FitTests: XCTestCase {
    func testPortraitTableOnAPhoneIsWidthBound() {
        let rect = RinkRenderer.fittedTableRect(
            tableSize: Vec2(100, 160), in: CGSize(width: 390, height: 844), margin: 12)
        XCTAssertEqual(rect.width, 366, accuracy: 1e-9)
        XCTAssertEqual(rect.height, 366 * 1.6, accuracy: 1e-9)
        XCTAssertEqual(rect.midX, 195, accuracy: 1e-9)
        XCTAssertEqual(rect.midY, 422, accuracy: 1e-9)
    }

    func testSquareTableOnALandscapeIPadIsHeightBound() {
        let rect = RinkRenderer.fittedTableRect(
            tableSize: Vec2(120, 120), in: CGSize(width: 1366, height: 1024), margin: 12)
        XCTAssertEqual(rect.height, 1000, accuracy: 1e-9)
        XCTAssertEqual(rect.width, 1000, accuracy: 1e-9)
        XCTAssertEqual(rect.midX, 683, accuracy: 1e-9)
    }

    func testADegenerateScreenGivesNoTable() {
        XCTAssertEqual(RinkRenderer.fittedTableRect(tableSize: Vec2(100, 160), in: .zero), .zero)
    }
}
