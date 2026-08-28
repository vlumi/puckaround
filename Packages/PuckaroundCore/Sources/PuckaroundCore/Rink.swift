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
        /// The faceoff ceremony: the puck is frozen at centre behind a force
        /// field, and play begins the instant every seat has readied. Carries
        /// who has readied so far, and — after a finished game — who just won,
        /// so the result stays on screen while the players decide on a rematch.
        /// A faceoff that follows a win resets the score when it starts (the
        /// rematch); the opening one has nothing to reset.
        case faceoff(ready: Set<PlayerID>, afterWin: PlayerID?)
        case playing

        static var opening: Phase { .faceoff(ready: [], afterWin: nil) }
    }

    public static let tickRate = 60
    public static let dt = 1.0 / Double(tickRate)
    /// Below this spin rate (rad/s) the puck stops rotating, so it settles.
    static let restAngularVelocity = 0.05
    /// How strongly a glancing mallet hit spins a shaped puck (0 = none). A feel
    /// dial for the shaped-puck spike.
    static let spinBite = 0.6

    public let table: Playfield
    public let lineup: Lineup
    public let rules: Rules
    public internal(set) var puck: Puck
    /// One per seat, in lineup order.
    public internal(set) var mallets: [Mallet]
    /// One per seat, in lineup order.
    public internal(set) var score: [Int]
    public internal(set) var phase: Phase = .playing
    public private(set) var tick: Tick = 0
    /// What happened this tick — cleared at the start of each `advance`, so it
    /// only ever describes the latest step. The feedback layers read it.
    public internal(set) var events: [GameEvent] = []
    /// Reserved seam: seeded, deterministic randomness for a sim that has none
    /// yet (the faceoff opening replaced the old random serve). The first
    /// randomised event — a bumper kick, a puck-variety wobble — draws from
    /// here. Note it participates in `Equatable`: two rinks differing only by
    /// seed are unequal even before any draw.
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
        phase = .opening
    }

    /// A seat declares itself ready. No take-backs — readiness is a latch. When
    /// the last seat readies, the force field drops and play begins that instant.
    public mutating func ready(_ player: PlayerID) {
        guard case .faceoff(var ready, let afterWin) = phase, lineup.contains(player) else {
            return
        }
        ready.insert(player)
        if ready.count == lineup.playerCount {
            // The rematch begins: a faceoff that followed a win clears the score
            // the instant it starts, so the final result stayed up until now.
            if afterWin != nil {
                score = lineup.players.map { _ in 0 }
            }
            phase = .playing
        } else {
            phase = .faceoff(ready: ready, afterWin: afterWin)
        }
    }

    /// Which seats have readied during the faceoff (empty otherwise).
    public var readySeats: Set<PlayerID> {
        if case .faceoff(let ready, _) = phase { return ready }
        return []
    }

    /// The winner still shown during a post-game faceoff (nil for the opening
    /// one, or during play). Drives the WIN/LOSE overlay.
    public var finalWinner: PlayerID? {
        if case .faceoff(_, let afterWin) = phase { return afterWin }
        return nil
    }

    public var isFaceoff: Bool {
        if case .faceoff = phase { return true }
        return false
    }

    /// After a goal: the puck is served from centre, gliding slowly into the
    /// conceder's half. It moves AWAY from every opponent — a 1v1 opponent can't
    /// cross the centre line, so a puck heading into the conceder's own end is
    /// unreachable by anyone but them until it settles.
    private mutating func serve(to player: PlayerID) {
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
        for player in lineup.players {
            moveMallet(of: player, by: inputs[player]?.malletDrag ?? .zero, strikes: playing)
        }
        // The puck may already be touching a resting mallet — but that is not a
        // NEW hit, so it emits no event; only a closing contact during a move does.
        if playing {
            stepPuck()
        }
    }

    /// The other seat scores; the conceder gets the puck, or the game ends.
    mutating func goal(against edge: Seat) {
        guard let conceder = lineup.players.first(where: { lineup.seat(of: $0) == edge }),
            let scorer = lineup.players.first(where: { $0 != conceder })
        else { return }
        score[scorer.rawValue] += 1
        events.append(.goal(scorer: scorer, conceder: conceder))
        if score[scorer.rawValue] >= rules.pointsToWin {
            // The game is won: show the result and open the rematch faceoff at
            // once. Readying up starts a fresh game (score resets then).
            phase = .faceoff(ready: [], afterWin: scorer)
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
