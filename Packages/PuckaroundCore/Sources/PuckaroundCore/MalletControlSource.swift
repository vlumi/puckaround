/// Identifies one finger for its whole down–move–up life.
public typealias TouchID = Int

/// A control scheme driven by touches. The capture layer feeds it id-tagged
/// points already in WORLD units; the sim only ever sees the `SeatInput` it
/// produces.
public protocol TouchDrivenControlSource: ControlSource, AnyObject {
    func touchBegan(id: TouchID, at location: Vec2)
    func touchMoved(id: TouchID, at location: Vec2)
    func touchEnded(id: TouchID)
    /// Drop every in-flight touch (new game, reset).
    func releaseAll()
}

/// **Drag the mallet.** A finger belongs to the seat it came down in for its
/// whole life — decided once at touch-down, never revisited, so a finger that
/// crosses the centre line never becomes the other player's. The FIRST finger
/// down in a seat's half drives that seat's mallet by its movement; any other
/// finger of the same seat is ignored until it lifts. Each tick the driving
/// finger's movement since the last read becomes the seat's drag.
public final class MalletControlSource: TouchDrivenControlSource {
    public var zones: SeatZones
    /// The finger driving each seat's mallet.
    private var driver: [PlayerID: TouchID] = [:]
    private var last: [TouchID: Vec2] = [:]
    /// Movement accumulated since the seat was last read.
    private var pending: [PlayerID: Vec2] = [:]

    public init(zones: SeatZones) {
        self.zones = zones
    }

    private func seat(driving id: TouchID) -> PlayerID? {
        driver.first(where: { $0.value == id })?.key
    }

    public func touchBegan(id: TouchID, at location: Vec2) {
        let seat = zones.owner(of: location)
        guard driver[seat] == nil else { return }
        driver[seat] = id
        last[id] = location
    }

    public func touchMoved(id: TouchID, at location: Vec2) {
        guard let previous = last[id], let seat = seat(driving: id) else { return }
        last[id] = location
        pending[seat, default: .zero] += location - previous
    }

    /// Movement not yet read is still delivered — a flick that ends between two
    /// ticks would otherwise lose its last, fastest segment.
    public func touchEnded(id: TouchID) {
        if let seat = seat(driving: id) {
            driver[seat] = nil
        }
        last[id] = nil
    }

    public func releaseAll() {
        driver.removeAll()
        last.removeAll()
        pending.removeAll()
    }

    public func input(for player: PlayerID, at tick: Tick) -> SeatInput {
        guard let drag = pending.removeValue(forKey: player), drag != .zero else { return .none }
        return SeatInput(malletDrag: drag)
    }
}
