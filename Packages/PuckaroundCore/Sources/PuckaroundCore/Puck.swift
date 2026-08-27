public struct Puck: Equatable, Codable, Sendable {
    public var position: Vec2
    /// World units per second.
    public var velocity: Vec2

    public init(position: Vec2, velocity: Vec2 = .zero) {
        self.position = position
        self.velocity = velocity
    }

    public var isMoving: Bool { velocity != .zero }
}
