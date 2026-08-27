/// Where each seat lives on the table: its edge, for owning touches, and a
/// band along that edge, for being drawn.
public struct SeatZones: Equatable, Sendable {
    public let lineup: Lineup
    /// The table, in world units.
    public let bounds: Rect

    public init(lineup: Lineup, bounds: Rect) {
        self.lineup = lineup
        self.bounds = bounds
    }

    /// The wall an edge sits on, as a segment — so a point beyond a corner is
    /// nearest the wall it is actually beside, not whichever infinite line it
    /// happens to line up with.
    public func wall(of edge: Seat) -> (a: Vec2, b: Vec2) {
        switch edge {
        case .bottom: return (Vec2(bounds.minX, bounds.maxY), Vec2(bounds.maxX, bounds.maxY))
        case .top: return (Vec2(bounds.minX, bounds.minY), Vec2(bounds.maxX, bounds.minY))
        case .left: return (Vec2(bounds.minX, bounds.minY), Vec2(bounds.minX, bounds.maxY))
        case .right: return (Vec2(bounds.maxX, bounds.minY), Vec2(bounds.maxX, bounds.maxY))
        }
    }

    /// Distance from `point` to an edge's wall.
    public func distance(from point: Vec2, to edge: Seat) -> Double {
        let (a, b) = wall(of: edge)
        return point.distance(toSegment: a, b)
    }

    /// The seat whose wall is nearest — a touch always belongs to somebody.
    /// Ties go to the lower seat, so the answer is deterministic.
    public func owner(of point: Vec2) -> PlayerID {
        var best = lineup.players[0]
        var bestDistance = distance(from: point, to: lineup.seat(of: best))
        for player in lineup.players.dropFirst() {
            let d = distance(from: point, to: lineup.seat(of: player))
            if d < bestDistance {
                best = player
                bestDistance = d
            }
        }
        return best
    }

    /// A seat's band: `depth` deep along its whole edge.
    public func band(for player: PlayerID, depth: Double) -> Rect {
        switch lineup.seat(of: player) {
        case .bottom:
            return Rect(x: bounds.minX, y: bounds.maxY - depth, width: bounds.width, height: depth)
        case .top:
            return Rect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: depth)
        case .left:
            return Rect(x: bounds.minX, y: bounds.minY, width: depth, height: bounds.height)
        case .right:
            return Rect(x: bounds.maxX - depth, y: bounds.minY, width: depth, height: bounds.height)
        }
    }
}
