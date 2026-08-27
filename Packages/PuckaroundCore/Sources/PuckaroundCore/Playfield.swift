/// The playfield: a walled rectangle in world units, plus the puck's physical
/// constants. World y grows DOWNWARD, matching screen space, so rendering is
/// one scale and nothing flips.
public struct Playfield: Equatable, Codable, Sendable {
    public var size: Vec2
    public var puckRadius: Double
    /// How far from the puck's edge a finger still counts as touching it.
    public var fingerRadius: Double
    /// Fraction of the normal speed kept through a wall bounce.
    public var restitution: Double
    /// Per-second exponential speed decay on the surface (0 = ice that never stops).
    public var drag: Double
    /// Speed cap, world units per second — so no strike can carry the puck
    /// through a wall in a single tick.
    public var maxSpeed: Double
    /// Below this the puck is at rest, so it never creeps forever on
    /// floating-point dust.
    public var restSpeed: Double
    /// The gentle push a serve gives.
    public var serveSpeed: Double

    public init(
        size: Vec2, puckRadius: Double, fingerRadius: Double, restitution: Double,
        drag: Double, maxSpeed: Double, restSpeed: Double, serveSpeed: Double
    ) {
        self.size = size
        self.puckRadius = puckRadius
        self.fingerRadius = fingerRadius
        self.restitution = restitution
        self.drag = drag
        self.maxSpeed = maxSpeed
        self.restSpeed = restSpeed
        self.serveSpeed = serveSpeed
    }

    /// Two players facing each other: a portrait table.
    public static let duel = Playfield(
        size: Vec2(100, 160), puckRadius: 4, fingerRadius: 5, restitution: 0.85,
        drag: 0.4, maxSpeed: 400, restSpeed: 0.5, serveSpeed: 30)

    /// Three or four players: a square, so no edge is favoured.
    public static let square = Playfield(
        size: Vec2(120, 120), puckRadius: 4, fingerRadius: 5, restitution: 0.85,
        drag: 0.4, maxSpeed: 400, restSpeed: 0.5, serveSpeed: 30)

    public static func standard(for lineup: Lineup) -> Playfield {
        lineup.playerCount == 2 ? .duel : .square
    }

    public var bounds: Rect { Rect(origin: .zero, size: size) }
    public var center: Vec2 { bounds.center }
    /// Where the puck's CENTRE may be: the bounds shrunk by its radius.
    public var puckField: Rect { bounds.insetBy(puckRadius) }
}
