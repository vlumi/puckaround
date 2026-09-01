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
    /// (parked at center) until everyone is ready and the field drops.
    public var faceoffBubbleRadius: Double
    /// How fast the puck glides into the conceder's half on a serve after a goal.
    public var serveSpeed: Double
    /// The pucks in play — one entry per puck, each its own silhouette, so a
    /// mixed table can fly a disc beside a tumbling square. One disc by default.
    public var puckShapes: [PuckShape]

    /// The single-puck view of `puckShapes`: reads the first, and setting it
    /// makes this a one-puck table of that shape.
    public var puckShape: PuckShape {
        get { puckShapes[0] }
        set { puckShapes = [newValue] }
    }
    /// How the long side walls behave — solid (bounce) by default, or wrap.
    public var sideWalls: SideWalls
    /// Pinball furniture: fixed discs the puck bounces off with a kick. Empty
    /// on the plain table; the arcade's tables seat a few.
    public var bumpers: [Bumper]
    /// The STARTING brick wall — the live wall is sim state on the `Rink`,
    /// since bricks break; it racks fresh from here each game and after every
    /// goal. Empty everywhere but breakout tables.
    public var bricks: [Brick]

    public init(
        size: Vec2, puckRadius: Double, malletRadius: Double, goalWidth: Double,
        restitution: Double, drag: Double, maxSpeed: Double, restSpeed: Double,
        faceoffBubbleRadius: Double, serveSpeed: Double, puckShapes: [PuckShape] = [.circle],
        doublesGoalWidth: Double? = nil, format: Format = .oneVsOne,
        sideWalls: SideWalls = .solid, bumpers: [Bumper] = [], bricks: [Brick] = []
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
        self.puckShapes = puckShapes
        self.doublesGoalWidth = doublesGoalWidth ?? goalWidth * 2.2
        self.format = format
        self.sideWalls = sideWalls
        self.bumpers = bumpers
        self.bricks = bricks
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
    /// Where the puck's CENTER may be: the bounds shrunk by its radius.
    public var puckField: Rect { bounds.insetBy(puckRadius) }

    /// Where a mallet slot's center may roam: its side's half of the table,
    /// inset by the mallet's radius so it can kiss the center line but not cross,
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

    /// The scoring mouth's width for a side: the goal opening minus a puck
    /// radius at each post, since the WHOLE disc must clear the posts to count.
    /// This is the width to DRAW, so what looks like the goal is what scores.
    public func goalMouthWidth(for side: Side) -> Double {
        max(0, goalWidth(for: side) - 2 * puckRadius)
    }

    /// The y a puck center must reach for the WHOLE puck to be past a short wall
    /// — the goal line fully crossed (soccer rules), so it warps back only after
    /// it is all the way in, not when its nose touches the line.
    public var topGoalLine: Double { -puckRadius }
    public var bottomGoalLine: Double { size.y + puckRadius }
}

/// A pinball bumper: a fixed disc the puck bounces off, taking a `kick` of
/// extra speed along the bounce normal — a mallet that never moves and hits
/// back. Table furniture, so any table (couch or arcade) can seat them.
public struct Bumper: Equatable, Codable, Sendable {
    public var position: Vec2
    public var radius: Double
    /// Speed added along the outgoing normal on a real hit, world units/s.
    public var kick: Double

    public init(position: Vec2, radius: Double, kick: Double) {
        self.position = position
        self.radius = radius
        self.kick = kick
    }
}

/// One brick of a breakout wall: an axis-aligned block the puck smashes — it
/// bounces off the face it hit, and the brick is gone. The table carries the
/// starting wall; the standing wall lives on the `Rink`, because state.
public struct Brick: Equatable, Codable, Sendable {
    public var rect: Rect

    public init(rect: Rect) {
        self.rect = rect
    }
}
