/// A finger's movement over the table during one tick, in world units.
public struct Swipe: Equatable, Codable, Sendable {
    public var from: Vec2
    public var to: Vec2
    /// World units per second — what the puck inherits if the swipe hits it.
    public var velocity: Vec2

    public init(from: Vec2, to: Vec2, velocity: Vec2) {
        self.from = from
        self.to = to
        self.velocity = velocity
    }
}

/// What one seat did this tick, as data — nothing about fingers or screens.
/// The sim decides what it meant (did the swipe hit the puck?).
public struct SeatInput: Equatable, Codable, Sendable {
    public var swipe: Swipe?

    public init(swipe: Swipe? = nil) {
        self.swipe = swipe
    }

    public static let none = SeatInput()
}

/// A control scheme is an input source, not a game mode. Fingers on glass, an
/// AI seat, anything else are all just ControlSources producing a `SeatInput`
/// per player per tick. The sim never knows which.
public protocol ControlSource {
    func input(for player: PlayerID, at tick: Tick) -> SeatInput
}
