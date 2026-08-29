/// What one seat did this tick, as data — nothing about fingers or screens.
public struct SeatInput: Equatable, Codable, Sendable {
    /// How far the seat wants its mallet moved this tick, in world units. A
    /// delta rather than a position: the mallet follows the hand's MOVEMENT,
    /// so a finger landing anywhere in the half drives it without a jump, and
    /// the sim clamps the result to the seat's own half.
    public var malletDrag: Vec2?

    public init(malletDrag: Vec2? = nil) {
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
