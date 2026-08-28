public struct Puck: Equatable, Codable, Sendable {
    public var position: Vec2
    /// World units per second.
    public var velocity: Vec2
    /// Orientation in radians; only meaningful for a polygon puck.
    public var angle: Double
    /// Radians per second.
    public var angularVelocity: Double

    public init(
        position: Vec2, velocity: Vec2 = .zero, angle: Double = 0, angularVelocity: Double = 0
    ) {
        self.position = position
        self.velocity = velocity
        self.angle = angle
        self.angularVelocity = angularVelocity
    }

    public var isMoving: Bool { velocity != .zero || angularVelocity != 0 }
}
