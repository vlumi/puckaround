import Foundation

/// The whole simulation: a table, a puck, the seats, and a fixed-timestep step
/// function. Deterministic by construction — same seed + same inputs → same
/// state, bit-for-bit — so a replay is just seed + per-tick inputs.
public struct Rink: Equatable, Sendable {
    public static let tickRate = 60
    public static let dt = 1.0 / Double(tickRate)

    public let table: Playfield
    public let lineup: Lineup
    public private(set) var puck: Puck
    public private(set) var tick: Tick = 0
    private var rng: SeededRNG

    public init(table: Playfield, lineup: Lineup, seed: UInt64) {
        self.table = table
        self.lineup = lineup
        self.rng = SeededRNG(seed: seed)
        self.puck = Puck(position: table.center)
        serve()
    }

    /// The puck back at centre with a gentle push in a random direction — so a
    /// fresh table is never dead-still, and the seed visibly matters.
    public mutating func serve() {
        let angle = Double.random(in: 0..<(2 * .pi), using: &rng)
        puck = Puck(position: table.center, velocity: Vec2(angle: angle) * table.serveSpeed)
    }

    /// One tick: every seat's input lands, then the puck moves.
    public mutating func advance(inputs: [PlayerID: SeatInput]) {
        // Seats apply in lineup order, never dictionary order — the order strikes
        // land in is part of the state.
        for player in lineup.players {
            guard let swipe = inputs[player]?.swipe else { continue }
            strike(with: swipe)
        }
        step()
        tick += 1
    }

    /// A swipe hits the puck when the segment it swept passes within reach of
    /// the puck's centre; the puck then takes the finger's velocity. A finger
    /// that isn't moving sweeps nothing and does nothing.
    private mutating func strike(with swipe: Swipe) {
        let reach = table.puckRadius + table.fingerRadius
        guard puck.position.distance(toSegment: swipe.from, swipe.to) <= reach else { return }
        puck.velocity = swipe.velocity
    }

    private mutating func step() {
        let dt = Rink.dt
        var v = puck.velocity
        let speed = v.length
        if speed > table.maxSpeed {
            v *= table.maxSpeed / speed
        }
        v *= exp(-table.drag * dt)
        if v.length < table.restSpeed {
            v = .zero
        }
        var p = puck.position + v * dt

        // Walls: reflect the position back inside and mirror that velocity
        // component, keeping `restitution` of it. Clamped after, so an extreme
        // step can never leave the field.
        let field = table.puckField
        if p.x < field.minX {
            p.x = field.minX + (field.minX - p.x)
            v.x = -v.x * table.restitution
        } else if p.x > field.maxX {
            p.x = field.maxX - (p.x - field.maxX)
            v.x = -v.x * table.restitution
        }
        if p.y < field.minY {
            p.y = field.minY + (field.minY - p.y)
            v.y = -v.y * table.restitution
        } else if p.y > field.maxY {
            p.y = field.maxY - (p.y - field.maxY)
            v.y = -v.y * table.restitution
        }
        puck = Puck(position: field.clamping(p), velocity: v)
    }
}
