import XCTest

@testable import PuckaroundCore

/// The machine: a deterministic sweep across its goal mouth.
final class PatternControlSourceTests: XCTestCase {
    private let source = PatternControlSource(table: .duel)

    /// The sweep holds its defensive line and never leaves the mouth's reach.
    func testTheSweepHoldsItsLine() {
        let table = Playfield.duel
        let reach = table.goalWidth(for: .top) / 2 + table.malletRadius
        for tick in 0..<300 {
            let p = source.position(at: Tick(tick))
            XCTAssertEqual(p.y, table.malletRadius * 2.5, accuracy: 1e-9)
            XCTAssertLessThanOrEqual(abs(p.x - table.center.x), reach + 1e-9)
        }
    }

    /// Over a full period the sweep actually covers the whole mouth.
    func testTheSweepCoversTheWholeMouth() {
        let table = Playfield.duel
        let reach = table.goalWidth(for: .top) / 2 + table.malletRadius
        let xs = (0..<200).map { source.position(at: Tick($0)).x }
        XCTAssertEqual(xs.max()!, table.center.x + reach, accuracy: 0.5)
        XCTAssertEqual(xs.min()!, table.center.x - reach, accuracy: 0.5)
    }

    /// Each tick's input pins the mallet to the pattern and swings it onward:
    /// the grab is last tick's spot, and grab plus drag is this tick's.
    func testInputPinsThePatternAndSwings() {
        for tick in [Tick(1), 30, 71, 240] {
            let input = source.input(for: .topSingle, at: tick)
            XCTAssertEqual(input.malletGrab, source.position(at: tick - 1))
            XCTAssertEqual(
                input.malletGrab! + input.malletDrag!, source.position(at: tick))
        }
    }

    /// The machine drives exactly one slot; everyone else gets nothing.
    func testOtherSlotsGetNothing() {
        XCTAssertEqual(source.input(for: .bottomSingle, at: 5), .none)
    }
}
