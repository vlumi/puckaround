/// Identifies one finger for its whole down–move–up life.
public typealias TouchID = Int

/// A control scheme driven by touches. The capture layer feeds it id-tagged
/// points already in WORLD units, with the event's timestamp; the sim only
/// ever sees the `SeatInput` it produces.
public protocol TouchDrivenControlSource: ControlSource, AnyObject {
    func touchBegan(id: TouchID, at location: Vec2, time: Double)
    func touchMoved(id: TouchID, at location: Vec2, time: Double)
    func touchEnded(id: TouchID)
    /// Drop every in-flight touch (lineup change, reset).
    func releaseAll()
}

/// **Swipe to strike.** A finger belongs to the seat it came down in for its
/// whole life — decided once at touch-down, never revisited, so a finger that
/// crosses the table never becomes somebody else's. Each tick, a finger's
/// movement since it was last read becomes that seat's `Swipe`; the sim
/// decides whether it hit the puck.
public final class SwipeControlSource: TouchDrivenControlSource {
    private struct Trail {
        var from: Vec2
        var fromTime: Double
        var to: Vec2
        var toTime: Double
        /// The finger has lifted; the trail is delivered once more, then dropped.
        var ended = false
    }

    public var zones: SeatZones
    private var owner: [TouchID: PlayerID] = [:]
    private var last: [TouchID: (point: Vec2, time: Double)] = [:]
    private var trails: [TouchID: Trail] = [:]

    public init(zones: SeatZones) {
        self.zones = zones
    }

    public func touchBegan(id: TouchID, at location: Vec2, time: Double) {
        owner[id] = zones.owner(of: location)
        last[id] = (location, time)
        trails[id] = nil
    }

    public func touchMoved(id: TouchID, at location: Vec2, time: Double) {
        guard let previous = last[id] else { return }
        last[id] = (location, time)
        if var trail = trails[id] {
            trail.to = location
            trail.toTime = time
            trails[id] = trail
        } else {
            trails[id] = Trail(
                from: previous.point, fromTime: previous.time, to: location, toTime: time)
        }
    }

    /// A lifted finger's unread movement is still delivered — a fast flick that
    /// ends between two ticks would otherwise lose its last, fastest segment.
    public func touchEnded(id: TouchID) {
        last[id] = nil
        if trails[id] != nil {
            trails[id]?.ended = true
        } else {
            owner[id] = nil
        }
    }

    public func releaseAll() {
        owner.removeAll()
        last.removeAll()
        trails.removeAll()
    }

    /// The seat's longest pending sweep, consumed. Any other finger of the same
    /// seat keeps its trail for the next tick.
    public func input(for player: PlayerID, at tick: Tick) -> SeatInput {
        var chosen: (id: TouchID, trail: Trail)?
        for (id, trail) in trails where owner[id] == player {
            let length = (trail.to - trail.from).lengthSquared
            if let current = chosen {
                let currentLength = (current.trail.to - current.trail.from).lengthSquared
                if length > currentLength || (length == currentLength && id < current.id) {
                    chosen = (id, trail)
                }
            } else {
                chosen = (id, trail)
            }
        }
        guard let (id, trail) = chosen else { return .none }
        trails[id] = nil
        if trail.ended {
            owner[id] = nil
        }
        guard trail.toTime > trail.fromTime else { return .none }
        let velocity = (trail.to - trail.from) * (1 / (trail.toTime - trail.fromTime))
        return SeatInput(swipe: Swipe(from: trail.from, to: trail.to, velocity: velocity))
    }
}
