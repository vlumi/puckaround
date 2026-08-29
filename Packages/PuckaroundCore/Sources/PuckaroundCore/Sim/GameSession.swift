import Foundation

/// Drives the deterministic sim from render-loop time: accumulates elapsed
/// wall time and steps the rink at its fixed timestep, however many ticks a
/// frame owes. Rendering reads the latest state; per-mallet input comes from
/// the injected provider — the sim never knows which scheme or finger produced
/// it.
///
/// Deliberately nothing `@Published`: the game view redraws every frame via
/// `TimelineView(.animation)` anyway, and publishing per-frame sim state would
/// mutate observable state mid-view-update.
@MainActor
public final class GameSession {
    /// A frame that owes more than this drops the rest: one long hitch costs a
    /// little sim time rather than a burst of catch-up ticks that stutters.
    public static let maxTicksPerFrame = 8

    public private(set) var rink: Rink
    private let inputFor: (MalletSlot, Tick) -> SeatInput
    private var lastTime: TimeInterval?
    private var owed: Double = 0

    /// While paused the sim holds: `update` re-anchors the clock each frame but
    /// steps nothing, so no wall time is owed and resuming never bursts to catch
    /// up. The render loop keeps running (the table still draws); only the sim
    /// is frozen.
    public var paused = false

    public init(rink: Rink, inputFor: @escaping (MalletSlot, Tick) -> SeatInput) {
        self.rink = rink
        self.inputFor = inputFor
    }

    /// Advance to `time` (seconds, any monotonic reference). The first call only
    /// anchors the clock; a paused session re-anchors and steps nothing.
    public func update(to time: TimeInterval) {
        guard let last = lastTime, !paused else {
            lastTime = time
            return
        }
        lastTime = time
        owed += max(0, time - last)
        var ticks = 0
        while owed >= Rink.dt, ticks < GameSession.maxTicksPerFrame {
            advance()
            owed -= Rink.dt
            ticks += 1
        }
        if ticks == GameSession.maxTicksPerFrame {
            owed = 0
        }
    }

    /// Exactly one tick, inputs gathered from every mallet.
    public func advance() {
        var inputs: [MalletSlot: SeatInput] = [:]
        for slot in rink.slots {
            inputs[slot] = inputFor(slot, rink.tick)
        }
        rink.advance(inputs: inputs)
    }

    public func ready(_ slot: MalletSlot) {
        rink.ready(slot)
    }

    public func newGame() {
        rink.newGame()
    }
}
