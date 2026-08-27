import XCTest

@testable import PuckaroundCore

final class SeededRNGTests: XCTestCase {
    func testSameSeedSameSequence() {
        var a = SeededRNG(seed: 7)
        var b = SeededRNG(seed: 7)
        for _ in 0..<100 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testDifferentSeedsDiverge() {
        var a = SeededRNG(seed: 1)
        var b = SeededRNG(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }

    /// Pinned so a change to the generator — which would silently change every
    /// serve — cannot pass unnoticed.
    func testKnownAnswer() {
        var rng = SeededRNG(seed: 0)
        XCTAssertEqual(rng.next(), 0xE220_A839_7B1D_CDAF)
    }
}
