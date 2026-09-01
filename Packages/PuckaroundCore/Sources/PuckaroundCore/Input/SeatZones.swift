/// Where each mallet slot lives on the table: which side and lane owns a touch.
/// Slot-based — a touch routes to a mallet, never to a "player".
public struct SeatZones: Equatable, Sendable {
    /// The slots on the table, in `Format.slots` order.
    public let slots: [MalletSlot]
    /// The table, in world units.
    public let bounds: Rect

    public init(format: Format, bounds: Rect) {
        self.slots = format.slots
        self.bounds = bounds
    }

    /// Which side a point falls in — the half of the table it is nearer to.
    /// World y grows down, so the lower half (larger y) is the bottom side.
    public func side(of point: Vec2) -> Side {
        point.y >= bounds.center.y ? .bottom : .top
    }

    /// The slot that owns a touch: its side's half, and — when that side fields
    /// two mallets — the lane (left/right of center) the touch falls in. Nil on
    /// an empty half (a solo table's machine end), where a touch drives nothing.
    public func owner(of point: Vec2) -> MalletSlot? {
        let side = side(of: point)
        let sideSlots = slots.filter { $0.side == side }
        guard sideSlots.count > 1 else { return sideSlots.first }
        // Two: left of center is the left lane, right of center the right.
        let lane: Lane = point.x < bounds.center.x ? .left : .right
        return sideSlots.first { $0.lane == lane } ?? sideSlots[0]
    }
}
