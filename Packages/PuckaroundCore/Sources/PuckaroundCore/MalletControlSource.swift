/// Identifies one finger for its whole down–move–up life.
public typealias TouchID = Int

/// A control scheme driven by touches. The capture layer feeds it id-tagged
/// points already in WORLD units, plus where the mallet the touch would drive
/// currently sits (so the source can decide to grab it or ignore the finger);
/// the sim only ever sees the `SeatInput` it produces.
public protocol TouchDrivenControlSource: ControlSource, AnyObject {
    func touchBegan(id: TouchID, at location: Vec2, malletAt: Vec2)
    func touchMoved(id: TouchID, at location: Vec2, malletAt: Vec2)
    func touchEnded(id: TouchID)
    /// Drop every in-flight touch (new game, reset).
    func releaseAll()
}

/// **Grab, then drag, the mallet.** A finger only takes a mallet when it comes
/// down (or later slides) NEAR it — within `grabRadius`. On the grab the mallet
/// snaps under the finger, then follows its movement; a finger that lands far
/// from the mallet is ignored until it swipes close, so a sloppy re-grab doesn't
/// drive the mallet from an offset. One finger per mallet: once a finger has it,
/// others in that zone wait, and the finger keeps it wherever it wanders.
public final class MalletControlSource: TouchDrivenControlSource {
    /// How near a finger must come to a mallet to grab it, in world units.
    /// Roomy — a thumb is wide, and a near-miss should still catch.
    public var grabRadius: Double
    public var zones: SeatZones
    /// The finger driving each mallet.
    private var driver: [MalletSlot: TouchID] = [:]
    private var last: [TouchID: Vec2] = [:]
    /// Movement accumulated since the mallet was last read.
    private var pending: [MalletSlot: Vec2] = [:]
    /// A fresh grab target (finger position) to snap the mallet to, once.
    private var grab: [MalletSlot: Vec2] = [:]

    public init(zones: SeatZones, grabRadius: Double = 20) {
        self.zones = zones
        self.grabRadius = grabRadius
    }

    private func slot(driving id: TouchID) -> MalletSlot? {
        driver.first(where: { $0.value == id })?.key
    }

    /// Try to attach an unassigned finger to the mallet in its zone if it is
    /// close enough — snapping the mallet under the finger.
    private func tryGrab(id: TouchID, at location: Vec2, malletAt: Vec2) {
        let slot = zones.owner(of: location)
        guard driver[slot] == nil, location.distance(to: malletAt) <= grabRadius else { return }
        driver[slot] = id
        grab[slot] = location
        last[id] = location
    }

    public func touchBegan(id: TouchID, at location: Vec2, malletAt: Vec2) {
        tryGrab(id: id, at: location, malletAt: malletAt)
    }

    public func touchMoved(id: TouchID, at location: Vec2, malletAt: Vec2) {
        guard let slot = slot(driving: id) else {
            // Not driving yet — a finger that began too far can still grab the
            // mallet by sliding into range.
            tryGrab(id: id, at: location, malletAt: malletAt)
            return
        }
        defer { last[id] = location }
        guard let previous = last[id] else { return }
        pending[slot, default: .zero] += location - previous
    }

    /// Movement not yet read is still delivered — a flick that ends between two
    /// ticks would otherwise lose its last, fastest segment.
    public func touchEnded(id: TouchID) {
        if let slot = slot(driving: id) {
            driver[slot] = nil
        }
        last[id] = nil
    }

    public func releaseAll() {
        driver.removeAll()
        last.removeAll()
        pending.removeAll()
        grab.removeAll()
    }

    public func input(for slot: MalletSlot, at tick: Tick) -> SeatInput {
        let grabTo = grab.removeValue(forKey: slot)
        let drag = pending.removeValue(forKey: slot)
        if grabTo == nil, drag == nil || drag == .zero { return .none }
        return SeatInput(malletGrab: grabTo, malletDrag: drag ?? .zero)
    }
}
