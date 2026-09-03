import XCTest

@testable import PuckaroundCore

/// Kits: stable auto-assignment and the one-step clash resolution.
final class PlayerKitTests: XCTestCase {
    /// Auto-assignment is deterministic, in range, and never self-clashing.
    func testAssignmentIsStableAndWellFormed() {
        for name in ["Aki", "Boa", "ヴィレ", "🦆", ""] {
            let kit = PlayerKit.assigned(to: name)
            XCTAssertEqual(kit, PlayerKit.assigned(to: name), "stable across calls")
            XCTAssertTrue((0..<PlayerKit.paletteCount).contains(kit.home))
            XCTAssertTrue((0..<PlayerKit.paletteCount).contains(kit.away))
            XCTAssertNotEqual(kit.home, kit.away)
        }
    }

    /// Shuffles are well-formed and never hand back the kit they replace.
    func testRandomKitIsWellFormedAndFresh() {
        var previous = PlayerKit(home: 0, away: 1)
        for _ in 0..<200 {
            let kit = PlayerKit.random(differingFrom: previous)
            XCTAssertTrue((0..<PlayerKit.paletteCount).contains(kit.home))
            XCTAssertTrue((0..<PlayerKit.paletteCount).contains(kit.away))
            XCTAssertNotEqual(kit.home, kit.away)
            XCTAssertNotEqual(kit, previous)
            previous = kit
        }
    }

    /// No clash: both ends wear their own home.
    func testDistinctHomesBothWearHome() {
        let resolved = PlayerKit.resolve(
            bottom: PlayerKit(home: 0, away: 1), top: PlayerKit(home: 2, away: 0))
        XCTAssertEqual(resolved.bottom, 0)
        XCTAssertEqual(resolved.top, 2)
    }

    /// A clash switches exactly the non-home side to its away.
    func testAClashSwitchesOnlyTheAwaySide() {
        let a = PlayerKit(home: 3, away: 5)
        let b = PlayerKit(home: 3, away: 6)
        let bottomHome = PlayerKit.resolve(bottom: a, top: b, homeSide: .bottom)
        XCTAssertEqual(bottomHome.bottom, 3)
        XCTAssertEqual(bottomHome.top, 6)
        let topHome = PlayerKit.resolve(bottom: a, top: b, homeSide: .top)
        XCTAssertEqual(topHome.bottom, 5)
        XCTAssertEqual(topHome.top, 3)
    }

    /// Even a corrupt kit (away == home) resolves to two distinct colors.
    func testADegenerateKitStillResolvesDistinct() {
        let broken = PlayerKit(home: 4, away: 4)
        let resolved = PlayerKit.resolve(
            bottom: PlayerKit(home: 4, away: 0), top: broken, homeSide: .bottom)
        XCTAssertNotEqual(resolved.bottom, resolved.top)
    }
}
