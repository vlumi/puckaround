import Foundation

/// Something worth a sound or a buzz, emitted by a tick. A pure function of
/// the sim, so replays and (any future) networked play get them for free — the
/// feedback layers consume them and the sim never imports AVFoundation or UIKit.
public enum GameEvent: Equatable, Sendable {
    /// A mallet struck the puck; `speed` is the closing speed of the hit.
    case malletHit(PlayerID, speed: Double)
    /// The puck bounced off a wall; `speed` is how fast it was going into it.
    case wallBounce(speed: Double)
    /// A goal went in against `conceder`, scored by `scorer`.
    case goal(scorer: PlayerID, conceder: PlayerID)
    /// The game just ended.
    case gameOver(winner: PlayerID)
}

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
        /// The opening ceremony: the puck is frozen at centre behind a force
        /// field, and play begins the instant every seat has readied. Carries
        /// who has readied so far.
        case faceoff(ready: Set<PlayerID>)
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
    /// What happened this tick — cleared at the start of each `advance`, so it
    /// only ever describes the latest step. The feedback layers read it.
    public private(set) var events: [GameEvent] = []
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

    /// Scores to zero, and open with a faceoff: the puck sits frozen at centre
    /// behind the force field until every seat readies. No chance decides the
    /// opening — the players do, by both grabbing in. The mallets stay where the
    /// hands left them.
    public mutating func newGame() {
        score = lineup.players.map { _ in 0 }
        puck = Puck(position: table.center)
        phase = .faceoff(ready: [])
    }

    /// A seat declares itself ready. No take-backs — readiness is a latch. When
    /// the last seat readies, the force field drops and play begins that instant.
    public mutating func ready(_ player: PlayerID) {
        guard case .faceoff(var ready) = phase, lineup.contains(player) else { return }
        ready.insert(player)
        phase = ready.count == lineup.playerCount ? .playing : .faceoff(ready: ready)
    }

    /// Which seats have readied during the faceoff (empty otherwise).
    public var readySeats: Set<PlayerID> {
        if case .faceoff(let ready) = phase { return ready }
        return []
    }

    public var isFaceoff: Bool {
        if case .faceoff = phase { return true }
        return false
    }

    /// After a goal: the puck is served from centre, gliding slowly into the
    /// conceder's half. It moves AWAY from every opponent — a 1v1 opponent can't
    /// cross the centre line, so a puck heading into the conceder's own end is
    /// unreachable by anyone but them until it settles.
    public mutating func serve(to player: PlayerID) {
        // Toward the conceder's own goal — away from centre and every opponent.
        let towardOwnGoal = -lineup.seat(of: player).inward
        puck = Puck(position: table.center, velocity: towardOwnGoal * table.serveSpeed)
    }

    /// One tick: every mallet moves (striking the puck on its way), then the
    /// puck moves. A finished game freezes only the puck — the mallets are the
    /// players' hands and stay live.
    public mutating func advance(inputs: [PlayerID: SeatInput]) {
        defer { tick += 1 }
        events.removeAll(keepingCapacity: true)
        let playing = phase == .playing
        // Seats apply in lineup order, never dictionary order — the order hits
        // land in is part of the state.
        for (index, player) in lineup.players.enumerated() {
            moveMallet(index, of: player, by: inputs[player]?.malletDrag ?? .zero, strikes: playing)
        }
        // The puck may already be touching a resting mallet — but that is not a
        // NEW hit, so it emits no event; only a closing contact during a move does.
        if playing {
            stepPuck()
        }
    }

    /// The mallet goes where the hand says, clamped to its half, and is swept
    /// along its path in steps no longer than the puck's radius — so a fast
    /// hand can't pass through the puck between two positions.
    ///
    /// During a faceoff the puck's force field is closed: the mallet is also
    /// clamped OUT of the bubble, and a finger driven into the bubble leaves the
    /// mallet stranded at the rim rather than warping it to the puck's edge — so
    /// nobody can ride a finger onto the puck the instant the field drops.
    private mutating func moveMallet(
        _ index: Int, of player: PlayerID, by drag: Vec2, strikes: Bool
    ) {
        let zone = table.malletZone(for: lineup.seat(of: player))
        let from = mallets[index].position
        var to = zone.clamping(from + drag)
        if isFaceoff {
            to = clampedOutOfBubble(to, seat: lineup.seat(of: player))
        }
        let velocity = (to - from) * (1 / Rink.dt)
        if strikes {
            let steps = max(1, Int(((to - from).length / table.puckRadius).rounded(.up)))
            for step in 1...steps {
                let at = from + (to - from) * (Double(step) / Double(steps))
                collidePuck(withMalletAt: at, velocity: velocity, by: player)
            }
        }
        mallets[index] = Mallet(position: to, velocity: velocity)
    }

    /// The nearest point to `p` that keeps the mallet's rim clear of the faceoff
    /// bubble around the puck. A point already inside is pushed back out to the
    /// rim — the mallet stops there, disconnected from the finger.
    private func clampedOutOfBubble(_ p: Vec2, seat: Seat) -> Vec2 {
        let keepOut = table.faceoffBubbleRadius + table.malletRadius
        let offset = p - puck.position
        let distance = offset.length
        guard distance < keepOut else { return p }
        // Push back along the offset; if the mallet is dead on the puck, push it
        // toward the seat's own goal (opposite its inward direction).
        let direction = distance > 0 ? offset * (1 / distance) : -seat.inward
        return puck.position + direction * keepOut
    }

    /// Circle–circle against a kinematic mallet: push the puck clear, and if
    /// they were closing, bounce it off with the mallet's motion added.
    private mutating func collidePuck(
        withMalletAt center: Vec2, velocity malletVelocity: Vec2, by player: PlayerID? = nil
    ) {
        let reach = table.puckRadius + table.malletRadius
        let offset = puck.position - center
        let distance = offset.length
        guard distance < reach else { return }
        let normal = distance > 0 ? offset * (1 / distance) : Vec2(0, -1)
        let clear = pushedClear(of: center, along: normal, reach: reach)
        puck.position = clear.position
        let closing = (puck.velocity - malletVelocity).dot(normal)
        if closing < 0 {
            puck.velocity -= normal * ((1 + table.restitution) * closing)
            if let player {
                events.append(.malletHit(player, speed: -closing))
            }
        }
        // Pinned against a wall: kill the speed aimed into it (the wall takes
        // it) and let it slide out ALONG the wall instead, so a hard slam
        // doesn't tunnel back through to the mallet's far side. Freeing a puck
        // that ends up STUCK on the wall is handled in `stepPuck`, once nothing
        // is holding it — a player can't get a mallet between puck and wall, so
        // the sim must peel it off itself.
        if let wall = clear.wall {
            let into = puck.velocity.dot(wall)
            if into > 0 {
                let along = (puck.position - center - wall * (puck.position - center).dot(wall))
                    .normalized
                puck.velocity = puck.velocity - wall * into + along * into
            }
        }
    }

    /// Peel a stuck puck off a wall. A puck resting on a wall with no speed off
    /// it — glued there, or only sliding along — can never be freed by a mallet
    /// (a player can't reach between it and the boards), so the sim does it:
    /// once no mallet is touching the puck, give it a brisk shove inward, enough
    /// to clear its own radius before drag eats it. Called at the end of a tick,
    /// so a mallet actively holding the puck against the wall keeps it there and
    /// it pops free the instant the mallet lifts.
    private mutating func freeStuckPuckFromWall() {
        let field = table.puckField
        var inward = Vec2.zero
        if puck.position.x <= field.minX + 1e-6 { inward.x = 1 }
        if puck.position.x >= field.maxX - 1e-6 { inward.x = -1 }
        if puck.position.y <= field.minY + 1e-6 { inward.y = 1 }
        if puck.position.y >= field.maxY - 1e-6 { inward.y = -1 }
        guard inward != .zero else { return }
        let escapeSpeed = table.puckRadius * 2
        guard puck.velocity.dot(inward) < escapeSpeed else { return }
        // Held by a mallet still overlapping it? Leave it — it pops free next
        // tick once the mallet moves off.
        let reach = table.puckRadius + table.malletRadius
        if mallets.contains(where: { puck.position.distance(to: $0.position) < reach }) { return }
        puck.position += inward * (table.puckRadius * 0.5)
        puck.velocity += inward * (escapeSpeed - puck.velocity.dot(inward))
        puck.position = field.clamping(puck.position)
    }

    /// Where the puck goes to be clear of a mallet at `center`: straight out
    /// along `normal` — unless that is through a wall. **A puck pinned against
    /// a wall slides along it** until it is clear of the mallet, as a real one
    /// squirts out sideways; `wall` is then that wall's outward normal. Pushing
    /// it through the wall instead let the wall reflection mirror it back to
    /// the mallet's far side, where it left backwards at speed — "the mallet
    /// warped through the puck".
    private func pushedClear(of center: Vec2, along normal: Vec2, reach: Double) -> (
        position: Vec2, wall: Vec2?
    ) {
        let field = table.puckField
        let free = center + normal * reach
        guard !field.contains(free) else { return (free, nil) }
        var target = field.clamping(free)
        let d = target - center
        let wall: Vec2
        if target.x != free.x {
            wall = Vec2(free.x > field.maxX ? 1 : -1, 0)
        } else {
            wall = Vec2(0, free.y > field.maxY ? 1 : -1)
        }
        guard d.lengthSquared < reach * reach else { return (target, wall) }
        // Slide along the wall the clamp hit: solve the other coordinate so the
        // distance is exactly `reach`, keeping the puck on the side it was on.
        if wall.x != 0 {
            let dy = max(0, reach * reach - d.x * d.x).squareRoot()
            target.y = center.y + (d.y >= 0 ? dy : -dy)
        } else {
            let dx = max(0, reach * reach - d.y * d.y).squareRoot()
            target.x = center.x + (d.x >= 0 ? dx : -dx)
        }
        // In a corner the slide may hit the other wall too; inside beats clear.
        return (field.clamping(target), wall)
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
            events.append(.wallBounce(speed: abs(v.y)))
            v.y = -v.y * table.restitution
        } else if p.y > field.maxY {
            if table.isInGoalMouth(x: p.x) {
                goal(against: .bottom)
                return
            }
            p.y = field.maxY - (p.y - field.maxY)
            events.append(.wallBounce(speed: abs(v.y)))
            v.y = -v.y * table.restitution
        }
        if p.x < field.minX {
            p.x = field.minX + (field.minX - p.x)
            events.append(.wallBounce(speed: abs(v.x)))
            v.x = -v.x * table.restitution
        } else if p.x > field.maxX {
            p.x = field.maxX - (p.x - field.maxX)
            events.append(.wallBounce(speed: abs(v.x)))
            v.x = -v.x * table.restitution
        }
        puck = Puck(position: field.clamping(p), velocity: v)

        // The puck may have moved into a resting mallet.
        for mallet in mallets {
            collidePuck(withMalletAt: mallet.position, velocity: mallet.velocity)
        }
        // …and if it ended the tick stuck against a wall with nothing holding
        // it, peel it off — a mallet can never reach between puck and boards.
        freeStuckPuckFromWall()
    }

    /// The other seat scores; the conceder gets the puck, or the game ends.
    private mutating func goal(against edge: Seat) {
        guard let conceder = lineup.players.first(where: { lineup.seat(of: $0) == edge }),
            let scorer = lineup.players.first(where: { $0 != conceder })
        else { return }
        score[scorer.rawValue] += 1
        events.append(.goal(scorer: scorer, conceder: conceder))
        if score[scorer.rawValue] >= rules.pointsToWin {
            phase = .finished(winner: scorer)
            puck = Puck(position: table.center)
            events.append(.gameOver(winner: scorer))
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
