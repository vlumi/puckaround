import Foundation

/// The rules that aren't geometry.
public struct Rules: Equatable, Codable, Sendable {
    public var pointsToWin: Int

    public init(pointsToWin: Int = 7) {
        self.pointsToWin = pointsToWin
    }

    /// Standard air hockey: first to seven.
    public static let standard = Rules()
}

/// The whole simulation: a table, a puck, two mallets, the score, and a
/// fixed-timestep step function. Deterministic by construction — same seed +
/// same inputs → same state, bit-for-bit — so a replay is just seed + per-tick
/// inputs.
public struct Rink: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case playing
        case finished(winner: PlayerID)
    }

    public static let tickRate = 60
    public static let dt = 1.0 / Double(tickRate)

    public let table: Playfield
    public let lineup: Lineup
    public let rules: Rules
    public private(set) var puck: Puck
    /// One per seat, in lineup order.
    public private(set) var mallets: [Mallet]
    /// One per seat, in lineup order.
    public private(set) var score: [Int]
    public private(set) var phase: Phase = .playing
    public private(set) var tick: Tick = 0
    private var rng: SeededRNG

    /// Only the duel is built: two seats, a goal each. `Lineup` models more
    /// seats for later, but the table has nowhere to put their goals yet.
    public init(table: Playfield, lineup: Lineup, rules: Rules = .standard, seed: UInt64) {
        precondition(lineup.playerCount == 2, "only 1v1 air hockey is built")
        self.table = table
        self.lineup = lineup
        self.rules = rules
        self.rng = SeededRNG(seed: seed)
        self.puck = Puck(position: table.center)
        self.mallets = lineup.players.map {
            Mallet(position: table.malletZone(for: lineup.seat(of: $0)).center)
        }
        self.score = lineup.players.map { _ in 0 }
        newGame()
    }

    public func mallet(of player: PlayerID) -> Mallet { mallets[player.rawValue] }
    public func score(of player: PlayerID) -> Int { score[player.rawValue] }

    /// Scores to zero, mallets home, and the opening possession decided by the
    /// seed — the one place chance enters.
    public mutating func newGame() {
        score = lineup.players.map { _ in 0 }
        phase = .playing
        mallets = lineup.players.map {
            Mallet(position: table.malletZone(for: lineup.seat(of: $0)).center)
        }
        let first = lineup.players[Int.random(in: 0..<lineup.playerCount, using: &rng)]
        serve(to: first)
    }

    /// The puck at rest in `player`'s half, theirs to push off.
    public mutating func serve(to player: PlayerID) {
        puck = Puck(position: table.serveSpot(for: lineup.seat(of: player)))
    }

    /// One tick: every mallet moves (striking the puck on its way), then the
    /// puck moves. A finished game is frozen.
    public mutating func advance(inputs: [PlayerID: SeatInput]) {
        defer { tick += 1 }
        guard phase == .playing else { return }
        // Seats apply in lineup order, never dictionary order — the order hits
        // land in is part of the state.
        for (index, player) in lineup.players.enumerated() {
            moveMallet(index, of: player, by: inputs[player]?.malletDrag ?? .zero)
        }
        stepPuck()
    }

    /// The mallet goes where the hand says, clamped to its half, and is swept
    /// along its path in steps no longer than the puck's radius — so a fast
    /// hand can't pass through the puck between two positions.
    private mutating func moveMallet(_ index: Int, of player: PlayerID, by drag: Vec2) {
        let zone = table.malletZone(for: lineup.seat(of: player))
        let from = mallets[index].position
        let to = zone.clamping(from + drag)
        let velocity = (to - from) * (1 / Rink.dt)
        let steps = max(1, Int(((to - from).length / table.puckRadius).rounded(.up)))
        for step in 1...steps {
            let at = from + (to - from) * (Double(step) / Double(steps))
            collidePuck(withMalletAt: at, velocity: velocity)
        }
        mallets[index] = Mallet(position: to, velocity: velocity)
    }

    /// Circle–circle against a kinematic mallet: push the puck clear, and if
    /// they were closing, bounce it off with the mallet's motion added.
    private mutating func collidePuck(withMalletAt center: Vec2, velocity malletVelocity: Vec2) {
        let reach = table.puckRadius + table.malletRadius
        let offset = puck.position - center
        let distance = offset.length
        guard distance < reach else { return }
        let normal = distance > 0 ? offset * (1 / distance) : Vec2(0, -1)
        puck.position = center + normal * reach
        let closing = (puck.velocity - malletVelocity).dot(normal)
        if closing < 0 {
            puck.velocity -= normal * ((1 + table.restitution) * closing)
        }
    }

    private mutating func stepPuck() {
        var v = puck.velocity
        let speed = v.length
        if speed > table.maxSpeed {
            v *= table.maxSpeed / speed
        }
        v *= exp(-table.drag * Rink.dt)
        if v.length < table.restSpeed {
            v = .zero
        }
        var p = puck.position + v * Rink.dt

        // The short walls carry the goals: a puck crossing one inside the mouth
        // is a goal against the seat at that wall; anywhere else it's a post or
        // wall and bounces. Long walls always bounce. Reflection mirrors the
        // position back inside and the velocity component with it, keeping
        // `restitution` of it.
        let field = table.puckField
        if p.y < field.minY {
            if table.isInGoalMouth(x: p.x) {
                goal(against: .top)
                return
            }
            p.y = field.minY + (field.minY - p.y)
            v.y = -v.y * table.restitution
        } else if p.y > field.maxY {
            if table.isInGoalMouth(x: p.x) {
                goal(against: .bottom)
                return
            }
            p.y = field.maxY - (p.y - field.maxY)
            v.y = -v.y * table.restitution
        }
        if p.x < field.minX {
            p.x = field.minX + (field.minX - p.x)
            v.x = -v.x * table.restitution
        } else if p.x > field.maxX {
            p.x = field.maxX - (p.x - field.maxX)
            v.x = -v.x * table.restitution
        }
        puck = Puck(position: field.clamping(p), velocity: v)

        // The puck may have moved into a resting mallet.
        for mallet in mallets {
            collidePuck(withMalletAt: mallet.position, velocity: mallet.velocity)
        }
    }

    /// The other seat scores; the conceder gets the puck, or the game ends.
    private mutating func goal(against edge: Seat) {
        guard let conceder = lineup.players.first(where: { lineup.seat(of: $0) == edge }),
            let scorer = lineup.players.first(where: { $0 != conceder })
        else { return }
        score[scorer.rawValue] += 1
        if score[scorer.rawValue] >= rules.pointsToWin {
            phase = .finished(winner: scorer)
            puck = Puck(position: table.center)
        } else {
            serve(to: conceder)
        }
    }
}

extension Rink {
    /// Test seams: stage a puck or a mallet by hand. `internal`, reached via
    /// `@testable import`; nothing shipped calls them.
    mutating func setPuckForTesting(_ puck: Puck) {
        self.puck = puck
    }

    mutating func setMalletForTesting(_ mallet: Mallet, of player: PlayerID) {
        mallets[player.rawValue] = mallet
    }
}
