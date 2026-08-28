/// The playfield: a walled rectangle in world units with a goal mouth in each
/// short wall, plus the puck's and mallets' physical constants. World y grows
/// DOWNWARD, matching screen space, so rendering is one scale and nothing
/// flips.
public struct Playfield: Equatable, Codable, Sendable {
    public var size: Vec2
    public var puckRadius: Double
    public var malletRadius: Double
    /// The opening in each short wall, centred on it.
    public var goalWidth: Double
    /// Fraction of the normal speed kept through a bounce (walls and mallets).
    public var restitution: Double
    /// Per-second exponential speed decay on the surface (0 = ice that never stops).
    public var drag: Double
    /// Speed cap, world units per second — so no hit can carry the puck
    /// through a wall in a single tick.
    public var maxSpeed: Double
    /// Below this the puck is at rest, so it never creeps forever on
    /// floating-point dust.
    public var restSpeed: Double
    /// The faceoff force field: no mallet may enter this radius around the puck
    /// (parked at centre) until everyone is ready and the field drops.
    public var faceoffBubbleRadius: Double
    /// How fast the puck glides into the conceder's half on a serve after a goal.
    public var serveSpeed: Double

    public init(
        size: Vec2, puckRadius: Double, malletRadius: Double, goalWidth: Double,
        restitution: Double, drag: Double, maxSpeed: Double, restSpeed: Double,
        faceoffBubbleRadius: Double, serveSpeed: Double
    ) {
        self.size = size
        self.puckRadius = puckRadius
        self.malletRadius = malletRadius
        self.goalWidth = goalWidth
        self.restitution = restitution
        self.drag = drag
        self.maxSpeed = maxSpeed
        self.restSpeed = restSpeed
        self.faceoffBubbleRadius = faceoffBubbleRadius
        self.serveSpeed = serveSpeed
    }

    /// The one table there is: two players facing each other.
    public static let duel = Playfield(
        size: Vec2(100, 160), puckRadius: 4, malletRadius: 7, goalWidth: 36,
        restitution: 0.85, drag: 0.4, maxSpeed: 400, restSpeed: 0.5, faceoffBubbleRadius: 22,
        serveSpeed: 26)

    public var bounds: Rect { Rect(origin: .zero, size: size) }
    public var center: Vec2 { bounds.center }
    /// Where the puck's CENTRE may be: the bounds shrunk by its radius.
    public var puckField: Rect { bounds.insetBy(puckRadius) }

    /// Where a seat's mallet centre may be: its own half of the table, inset by
    /// the mallet's radius — so the mallet can touch the centre line but never
    /// cross it.
    public func malletZone(for edge: Seat) -> Rect {
        let r = malletRadius
        let halfWidth = size.x / 2
        let halfHeight = size.y / 2
        switch edge {
        case .bottom:
            return Rect(x: r, y: halfHeight + r, width: size.x - 2 * r, height: halfHeight - 2 * r)
        case .top:
            return Rect(x: r, y: r, width: size.x - 2 * r, height: halfHeight - 2 * r)
        case .left:
            return Rect(x: r, y: r, width: halfWidth - 2 * r, height: size.y - 2 * r)
        case .right:
            return Rect(x: halfWidth + r, y: r, width: halfWidth - 2 * r, height: size.y - 2 * r)
        }
    }

    /// Whether a puck centre crossing a short wall at `x` goes cleanly into the
    /// goal mouth — clear of both posts, so the whole disc fits through.
    public func isInGoalMouth(x: Double) -> Bool {
        abs(x - center.x) <= goalWidth / 2 - puckRadius
    }
}
