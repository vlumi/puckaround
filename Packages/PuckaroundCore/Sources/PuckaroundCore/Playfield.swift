/// The playfield: a walled rectangle in world units with a goal mouth in each
/// short wall, plus the puck's and mallets' physical constants. World y grows
/// DOWNWARD, matching screen space, so rendering is one scale and nothing
/// flips.
public struct Playfield: Equatable, Codable, Sendable {
    public var size: Vec2
    public var puckRadius: Double
    public var malletRadius: Double
    /// The goal opening in singles (one defender). Doubles widens it — two
    /// defenders make a narrow goal trivial — via `doublesGoalWidth`.
    public var goalWidth: Double
    /// The wider goal opening for doubles (two defenders per side).
    public var doublesGoalWidth: Double
    /// How many hands each side fields — decides each side's goal width and how
    /// many mallet lanes it splits into.
    public var format: Format
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
    /// The puck's silhouette — circle by default; a polygon tumbles.
    public var puckShape: PuckShape

    public init(
        size: Vec2, puckRadius: Double, malletRadius: Double, goalWidth: Double,
        restitution: Double, drag: Double, maxSpeed: Double, restSpeed: Double,
        faceoffBubbleRadius: Double, serveSpeed: Double, puckShape: PuckShape = .circle,
        doublesGoalWidth: Double? = nil, format: Format = .oneVsOne
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
        self.puckShape = puckShape
        self.doublesGoalWidth = doublesGoalWidth ?? goalWidth * 2.2
        self.format = format
    }

    /// The one table there is: two players facing each other.
    public static let duel = Playfield(
        size: Vec2(100, 160), puckRadius: 4, malletRadius: 7, goalWidth: 36,
        restitution: 0.85, drag: 0.4, maxSpeed: 400, restSpeed: 0.5, faceoffBubbleRadius: 22,
        serveSpeed: 26, doublesGoalWidth: 78)

    /// This table set to a given format (which sides field two hands, and so
    /// which goals widen).
    public func with(format: Format) -> Playfield {
        var copy = self
        copy.format = format
        return copy
    }

    /// The opening in a side's goal: the narrow width when one hand defends it,
    /// the wide width when two do. A side's goal widens with its defenders, so
    /// in 1v2 the lone defender still faces a tight goal and the pair a broad
    /// one — the harder goal to keep goes to the side better staffed to keep it.
    public func goalWidth(for side: Side) -> Double {
        format.hands(on: side) == .two ? doublesGoalWidth : goalWidth
    }

    public var bounds: Rect { Rect(origin: .zero, size: size) }
    public var center: Vec2 { bounds.center }
    /// Where the puck's CENTRE may be: the bounds shrunk by its radius.
    public var puckField: Rect { bounds.insetBy(puckRadius) }

    /// Where a mallet slot's centre may roam: its side's half of the table,
    /// inset by the mallet's radius so it can kiss the centre line but not cross,
    /// and — in doubles — narrowed to its own left or right lane so two mallets
    /// of a side don't fight over the middle.
    public func malletZone(for slot: MalletSlot) -> Rect {
        let r = malletRadius
        let halfHeight = size.y / 2
        let top = slot.side == .bottom ? halfHeight + r : r
        let height = halfHeight - 2 * r
        switch slot.lane {
        case .full:
            return Rect(x: r, y: top, width: size.x - 2 * r, height: height)
        case .left:
            return Rect(x: r, y: top, width: size.x / 2 - r, height: height)
        case .right:
            return Rect(x: size.x / 2, y: top, width: size.x / 2 - r, height: height)
        }
    }

    /// Whether a puck centre crossing `side`'s short wall at `x` goes cleanly
    /// into that side's goal mouth — clear of both posts, so the whole disc fits
    /// through. Each side's goal has its own width (wider for two defenders).
    public func isInGoalMouth(x: Double, of side: Side) -> Bool {
        abs(x - center.x) <= goalWidth(for: side) / 2 - puckRadius
    }

    /// The y a puck centre must reach for the WHOLE puck to be past a short wall
    /// — the goal line fully crossed (soccer rules), so it warps back only after
    /// it is all the way in, not when its nose touches the line.
    public var topGoalLine: Double { -puckRadius }
    public var bottomGoalLine: Double { size.y + puckRadius }
}
