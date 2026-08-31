import Foundation

/// **The machine.** A mallet on a fixed pattern — a flat figure eight across
/// its goal mouth — for practicing against something honest: a drill target,
/// not a mind. It never aims, but careless shots come back off it all the
/// same, and its forward prowl reaches a puck that dies in front of it. A
/// pure function of the tick, so a practice game is as deterministic as any
/// other.
public struct PatternControlSource: ControlSource, Sendable {
    /// The slot the machine drives.
    public let slot: MalletSlot
    private let center: Vec2
    private let amplitude: Double
    /// The eight's half-height — how far the prowl leaves the patrol line.
    private let bob: Double
    /// Radians of sweep phase per tick — one full eight every `period` seconds.
    private let step: Double

    /// Traces a flat figure eight across `slot`'s goal mouth on `table` — a
    /// touch past each post, prowling about a patrol line three mallet-radii
    /// off the goal — one full eight per `period`.
    public init(
        table: Playfield, slot: MalletSlot = MalletSlot(side: .top, lane: .full),
        period: Double = 2.4
    ) {
        self.slot = slot
        // The bob stays half a radius shy of the inset, so the pattern never
        // presses the mallet into its own goal line.
        let inset = table.malletRadius * 3
        let y = slot.side == .top ? inset : table.size.y - inset
        self.center = Vec2(table.center.x, y)
        self.amplitude = table.goalWidth(for: slot.side) / 2 + table.malletRadius
        self.bob = table.malletRadius * 1.5
        self.step = 2 * .pi / (period * Double(Rink.tickRate))
    }

    /// Where the pattern puts the mallet at a tick: x sweeps once per period
    /// and y bobs twice — a 1:2 Lissajous, which is the flat eight.
    public func position(at tick: Tick) -> Vec2 {
        let phase = Double(tick) * step
        return center + Vec2(amplitude * sin(phase), bob * sin(2 * phase))
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
