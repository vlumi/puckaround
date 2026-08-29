/// What one seat did this tick, as data — nothing about fingers or screens.
public struct SeatInput: Equatable, Codable, Sendable {
    /// Where the seat wants its mallet snapped to this tick, in world units — a
    /// grab: a finger came down on (or near) the mallet, so it jumps under the
    /// thumb. Applied before `malletDrag`. Absent when there's no fresh grab.
    public var malletGrab: Vec2?
    /// How far the seat wants its mallet moved this tick, in world units. A
    /// delta rather than a position: the mallet follows the hand's MOVEMENT,
    /// so a finger dragging across the half drives it, and the sim clamps the
    /// result to the seat's own half.
    public var malletDrag: Vec2?

    public init(malletGrab: Vec2? = nil, malletDrag: Vec2? = nil) {
        self.malletGrab = malletGrab
        self.malletDrag = malletDrag
    }

    public static let none = SeatInput()
}

/// A control scheme is an input source, not a game mode. Fingers on glass, an
/// AI hand, anything else are all just ControlSources producing a `SeatInput`
/// per mallet per tick. The sim never knows which.
public protocol ControlSource {
    func input(for slot: MalletSlot, at tick: Tick) -> SeatInput
}
