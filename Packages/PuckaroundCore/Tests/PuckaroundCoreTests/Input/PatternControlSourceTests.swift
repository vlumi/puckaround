import XCTest

@testable import PuckaroundCore

/// The machine: a deterministic figure eight across its goal mouth.
final class PatternControlSourceTests: XCTestCase {
    private let source = PatternControlSource(table: .duel)

    /// The eight stays on its patch: x within the mouth's reach, y prowling
    /// about the patrol line without ever pressing into the goal.
    func testTheEightStaysOnItsPatch() {
        let table = Playfield.duel
        let reach = table.goalWidth(for: .top) / 2 + table.malletRadius
        for tick in 0..<300 {
            let p = source.position(at: Tick(tick))
            XCTAssertLessThanOrEqual(abs(p.x - table.center.x), reach + 1e-9)
            XCTAssertLessThanOrEqual(
                abs(p.y - table.malletRadius * 3), table.malletRadius * 1.5 + 1e-9)
            XCTAssertGreaterThanOrEqual(p.y, table.malletRadius * 1.5 - 1e-9)
        }
    }

    /// Over a full period the eight covers the whole mouth and actually
    /// prowls forward and back — an eight, not a line.
    func testTheEightCoversTheMouthAndProwls() {
        let table = Playfield.duel
        let reach = table.goalWidth(for: .top) / 2 + table.malletRadius
        let points = (0..<200).map { source.position(at: Tick($0)) }
        XCTAssertEqual(points.map(\.x).max()!, table.center.x + reach, accuracy: 0.5)
        XCTAssertEqual(points.map(\.x).min()!, table.center.x - reach, accuracy: 0.5)
        XCTAssertEqual(points.map(\.y).max()!, table.malletRadius * 4.5, accuracy: 0.5)
        XCTAssertEqual(points.map(\.y).min()!, table.malletRadius * 1.5, accuracy: 0.5)
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
