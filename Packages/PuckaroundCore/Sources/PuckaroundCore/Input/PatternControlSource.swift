import Foundation

/// **The machine.** A mallet on a fixed pattern — a metronome sweep across its
/// goal mouth — for practicing against something honest: a drill target, not a
/// mind. It never aims, but careless shots come back off it all the same. A
/// pure function of the tick, so a practice game is as deterministic as any
/// other.
public struct PatternControlSource: ControlSource, Sendable {
    /// The slot the machine drives.
    public let slot: MalletSlot
    private let center: Vec2
    private let amplitude: Double
    /// Radians of sweep phase per tick — one full pass every `period` seconds.
    private let step: Double

    /// Sweeps `slot`'s goal mouth on `table` — a touch past each post, parked a
    /// couple of mallet-widths off the goal line — one full pass per `period`.
    public init(
        table: Playfield, slot: MalletSlot = MalletSlot(side: .top, lane: .full),
        period: Double = 2.4
    ) {
        self.slot = slot
        let inset = table.malletRadius * 2.5
        let y = slot.side == .top ? inset : table.size.y - inset
        self.center = Vec2(table.center.x, y)
        self.amplitude = table.goalWidth(for: slot.side) / 2 + table.malletRadius
        self.step = 2 * .pi / (period * Double(Rink.tickRate))
    }

    /// Where the pattern puts the mallet at a tick.
    public func position(at tick: Tick) -> Vec2 {
        center + Vec2(amplitude * sin(Double(tick) * step), 0)
    }

    public func input(for slot: MalletSlot, at tick: Tick) -> SeatInput {
        guard slot == self.slot else { return .none }
        // Grab to last tick's spot, drag to this one: the grab pins the mallet
        // back onto the pattern (whatever clamped it off meanwhile), and the
        // drag is the swing that strikes.
        let from = position(at: tick - 1)
        return SeatInput(malletGrab: from, malletDrag: position(at: tick) - from)
    }
}
