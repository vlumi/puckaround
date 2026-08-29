import Foundation

/// Something worth a sound or a buzz, emitted by a tick. A pure function of
/// the sim, so replays and (any future) networked play get them for free — the
/// feedback layers consume them and the sim never imports AVFoundation or UIKit.
public enum GameEvent: Equatable, Sendable {
    /// A mallet struck the puck; `speed` is the closing speed of the hit. The
    /// slot says which mallet — the feedback layers color by its side.
    case malletHit(MalletSlot, speed: Double)
    /// The puck bounced off a wall; `speed` is how fast it was going into it.
    case wallBounce(speed: Double)
    /// A goal went in against `conceder`, scored by `scorer`. On an own goal the
    /// two are opposite sides all the same — the puck crossing a side's own line
    /// is the other side's point, whoever last touched it.
    case goal(scorer: Side, conceder: Side)
    /// The game just ended, won by a side.
    case gameOver(winner: Side)
    /// The faceoff cleared and play begins this tick — the "GO".
    case faceoffCleared
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

/// The whole simulation: a table, a puck, one mallet per slot, a score per
/// side, and a fixed-timestep step function. Deterministic by construction —
/// same seed + same inputs → same state, bit-for-bit — so a replay is just
/// seed + per-tick inputs.
///
/// The sim knows nothing of players or teams: a mallet is only its slot, a goal
/// is only its side. Who holds a mallet, and what "team" means, is a couch/UI
/// matter that never reaches here — one side wins, the other loses, and that
/// identity ends when the table does.
public struct Rink: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        /// The faceoff ceremony: the puck is frozen at center behind a force
        /// field, and play begins the instant every mallet has readied. Carries
        /// which mallets have readied so far, and — after a finished game — who
        /// just won, so the result stays on screen while the table decides on a
        /// rematch. A faceoff that follows a win resets the score when it starts
        /// (the rematch); the opening one has nothing to reset.
        case faceoff(ready: Set<MalletSlot>, afterWin: Side?)
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
    /// The same for a round puck — english on the disc. Gentler than a polygon's:
    /// a disc has no corners to catch, so it takes spin less readily. A feel dial.
    static let discSpinBite = 0.3
    /// How much a spinning disc's bounce angle is skewed by its spin, per rad/s
    /// (0 = a plain mirror bounce). Gentler than the polygon steer model; a flat
    /// wall can't curve the puck along it the way the ellipse's will. Feel dial.
    static let discSteerPerSpin = 0.015
    /// Fraction of a disc's spin that survives a wall bounce — the wall's grip
    /// bleeds the rest. Below 1 so spin doesn't persist forever off the boards.
    static let discSpinKeptOnBounce = 0.8

    /// The spin bite for the puck's own shape.
    var spinBite: Double {
        if case .circle = table.puckShape { return Rink.discSpinBite }
        return Rink.spinBite
    }

    public let table: Playfield
    public let rules: Rules
    /// The mallet slots on the table this game, in `Format.slots` order. Fixed
    /// for the life of the rink, so `mallets`, iteration, and hit order are all
    /// deterministic.
    public let slots: [MalletSlot]
    public internal(set) var puck: Puck
    /// One per slot, in `slots` order.
    public internal(set) var mallets: [Mallet]
    /// One score per side, indexed by `Rink.scoreOrder` (bottom, top).
    public internal(set) var score: [Int]
    public internal(set) var phase: Phase = .playing
    public private(set) var tick: Tick = 0
    /// What happened this tick — cleared at the start of each `advance`, so it
    /// only ever describes the latest step. The feedback layers read it.
    public internal(set) var events: [GameEvent] = []
    /// Set when the faceoff clears (`ready` fills the last slot), so the next
    /// `advance` — the first tick of play — emits the "GO". `ready` runs between
    /// ticks, outside the event stream, so it can't emit directly.
    private var announceFaceoffCleared = false
    /// Reserved seam: seeded, deterministic randomness for a sim that has none
    /// yet (the faceoff opening replaced the old random serve). The first
    /// randomised event — a bumper kick, a puck-variety wobble — draws from
    /// here. Note it participates in `Equatable`: two rinks differing only by
    /// seed are unequal even before any draw.
    private var rng: SeededRNG

    /// The two sides in a fixed order, so `score` is a plain array the sim can
    /// index deterministically.
    static let scoreOrder: [Side] = [.bottom, .top]

    public init(table: Playfield, rules: Rules = .standard, seed: UInt64) {
        self.table = table
        self.rules = rules
        self.slots = table.format.slots
        self.rng = SeededRNG(seed: seed)
        self.puck = Puck(position: table.center)
        self.mallets = slots.map { Mallet(position: table.malletZone(for: $0).center) }
        self.score = Rink.scoreOrder.map { _ in 0 }
        newGame()
    }

    public func mallet(at slot: MalletSlot) -> Mallet? {
        slots.firstIndex(of: slot).map { mallets[$0] }
    }

    public func score(of side: Side) -> Int {
        score[Rink.scoreOrder.firstIndex(of: side)!]
    }

    /// Scores to zero, and open with a faceoff: the puck sits frozen at center
    /// behind the force field until every mallet readies. No chance decides the
    /// opening — the players do, by all grabbing in. The mallets stay where the
    /// hands left them.
    public mutating func newGame() {
        score = Rink.scoreOrder.map { _ in 0 }
        puck = Puck(position: table.center)
        phase = .opening
    }

    /// A mallet declares itself ready. No take-backs — readiness is a latch.
    /// When the last mallet readies, the force field drops and play begins that
    /// instant.
    public mutating func ready(_ slot: MalletSlot) {
        guard case .faceoff(var ready, let afterWin) = phase, slots.contains(slot) else {
            return
        }
        ready.insert(slot)
        if ready.count == slots.count {
            // The rematch begins: a faceoff that followed a win clears the score
            // the instant it starts, so the final result stayed up until now.
            if afterWin != nil {
                score = Rink.scoreOrder.map { _ in 0 }
            }
            phase = .playing
            announceFaceoffCleared = true
        } else {
            phase = .faceoff(ready: ready, afterWin: afterWin)
        }
    }

    /// Which mallets have readied during the faceoff (empty otherwise).
    public var readyMallets: Set<MalletSlot> {
        if case .faceoff(let ready, _) = phase { return ready }
        return []
    }

    /// The winning side still shown during a post-game faceoff (nil for the
    /// opening one, or during play). Drives the WIN/LOSE overlay.
    public var finalWinner: Side? {
        if case .faceoff(_, let afterWin) = phase { return afterWin }
        return nil
    }

    public var isFaceoff: Bool {
        if case .faceoff = phase { return true }
        return false
    }

    /// After a goal: the puck is served from center, gliding slowly into the
    /// conceder's half. It moves AWAY from the far side — a puck heading into
    /// the conceder's own end is unreachable by the opponent until it settles.
    private mutating func serve(to side: Side) {
        let towardOwnGoal = -side.inward
        puck = Puck(position: table.center, velocity: towardOwnGoal * table.serveSpeed)
    }

    /// One tick: every mallet moves (striking the puck on its way), then the
    /// puck moves. A finished game freezes only the puck — the mallets are the
    /// players' hands and stay live.
    public mutating func advance(inputs: [MalletSlot: SeatInput]) {
        defer { tick += 1 }
        events.removeAll(keepingCapacity: true)
        let playing = phase == .playing
        if announceFaceoffCleared {
            events.append(.faceoffCleared)
            announceFaceoffCleared = false
        }
        // Mallets apply in slot order, never dictionary order — the order hits
        // land in is part of the state.
        for index in slots.indices {
            let input = inputs[slots[index]]
            moveMallet(
                at: index, grabTo: input?.malletGrab, by: input?.malletDrag ?? .zero,
                strikes: playing)
        }
        // The puck may already be touching a resting mallet — but that is not a
        // NEW hit, so it emits no event; only a closing contact during a move does.
        if playing {
            stepPuck()
        }
    }

    /// A goal against `side`: that side concedes, the opposite side scores; the
    /// conceder gets the puck, or the game ends.
    mutating func goal(against side: Side) {
        let conceder = side
        let scorer = side.opponent
        score[Rink.scoreOrder.firstIndex(of: scorer)!] += 1
        events.append(.goal(scorer: scorer, conceder: conceder))
        if score(of: scorer) >= rules.pointsToWin {
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

    mutating func setMalletForTesting(_ mallet: Mallet, at slot: MalletSlot) {
        guard let index = slots.firstIndex(of: slot) else { return }
        mallets[index] = mallet
    }
}
