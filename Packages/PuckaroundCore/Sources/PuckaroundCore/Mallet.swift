/// A player's striker: dragged, never thrown. Kinematic — infinitely heavy as
/// far as the puck is concerned — so it moves exactly where the hand puts it
/// and the puck bounces off it.
public struct Mallet: Equatable, Codable, Sendable {
    public var position: Vec2
    /// World units per second, over the last tick — what the puck feels.
    public var velocity: Vec2

    public init(position: Vec2, velocity: Vec2 = .zero) {
        self.position = position
        self.velocity = velocity
    }
}
