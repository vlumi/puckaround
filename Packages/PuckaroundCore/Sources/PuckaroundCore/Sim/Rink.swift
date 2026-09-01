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
    /// Two pucks clacked into each other; `speed` is their closing speed.
    case puckHit(speed: Double)
    /// The puck hit a bumper, which kicked it; `speed` is the closing speed.
    /// The arcade's score-attack loop feeds on these.
    case bumperHit(speed: Double)
    /// A goal went in against `conceder`, scored by `scorer`. On an own goal the
    /// two are opposite sides all the same — the puck crossing a side's own line
    /// is the other side's point, whoever last touched it.
    case goal(scorer: Side, conceder: Side)
    /// A game ended, won by a side, but the match continues (best-of play).
    case gameWon(winner: Side)
    /// The whole match ended, won by a side (its last game just finished).
    case matchOver(winner: Side)
    /// The faceoff cleared and play begins this tick — the "GO".
    case faceoffCleared
}

/// The rules that aren't geometry. A match is first to `gamesToWin` games; each
/// game is first to `pointsToWin` points. A single game is `gamesToWin == 1`.
public struct Rules: Equatable, Codable, Sendable {
    public var pointsToWin: Int
    public var gamesToWin: Int
    /// Who gets the serve after a goal: nil is standard air hockey (the
    /// conceder), a side pins every serve there — practice serves the human,
    /// so nobody waits on the machine to knock a serve back into play.
    public var serveTo: Side?

    public init(pointsToWin: Int = 7, gamesToWin: Int = 1, serveTo: Side? = nil) {
        self.pointsToWin = pointsToWin
        self.gamesToWin = gamesToWin
        self.serveTo = serveTo
    }

    /// Standard air hockey: a single game, first to seven.
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
        /// which mallets have readied so far and — after a finished game — the
        /// result just posted, so it stays on screen while the table decides to
        /// go again. Readying up clears the game score; if that result ended the
        /// whole MATCH, it also clears the games tally (a fresh match).
        case faceoff(ready: Set<MalletSlot>, afterWin: Outcome?)
        case playing

        static var opening: Phase { .faceoff(ready: [], afterWin: nil) }
    }

    /// A finished game's result, shown on the faceoff that follows it.
    public struct Outcome: Equatable, Sendable {
        public let winner: Side
        /// True if this game won the match (so the next faceoff starts a fresh
        /// match, tally and all); false if the match continues.
        public let endedMatch: Bool
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

    /// The spin bite for a given puck shape.
    func spinBite(for shape: PuckShape) -> Double {
        if case .circle = shape { return Rink.discSpinBite }
        return Rink.spinBite
    }

    public let table: Playfield
    public let rules: Rules
    /// The mallet slots on the table this game, in `Format.slots` order. Fixed
    /// for the life of the rink, so `mallets`, iteration, and hit order are all
    /// deterministic.
    public let slots: [MalletSlot]
    /// Every puck in play, in a fixed order — most tables fly one, a chaotic one
    /// up to three. The order is part of the state: physics resolves them by
    /// index, so the mayhem stays deterministic.
    public internal(set) var pucks: [Puck]
    /// The first puck — the whole story on a one-puck table.
    public var puck: Puck { pucks[0] }
    /// One per slot, in `slots` order.
    public internal(set) var mallets: [Mallet]
    /// One score per side, indexed by `Rink.scoreOrder` (bottom, top).
    public internal(set) var score: [Int]
    /// Games won per side this match, indexed by `Rink.scoreOrder`. In a single
    /// game (`gamesToWin == 1`) it just reads 1–0 at the end.
    public internal(set) var gamesWon: [Int]
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
    /// randomized event — a bumper kick, a puck-variety wobble — draws from
    /// here. Note it participates in `Equatable`: two rinks differing only by
    /// seed are unequal even before any draw.
    private var rng: SeededRNG

    /// The two sides in a fixed order, so `score` is a plain array the sim can
    /// index deterministically.
    static let scoreOrder: [Side] = [.bottom, .top]

    /// A side's slot in the per-side tallies — `scoreOrder` as a total function,
    /// so indexing needs no search and no unwrap (a test pins the two together).
    static func tallyIndex(_ side: Side) -> Int { side == .bottom ? 0 : 1 }

    public init(table: Playfield, rules: Rules = .standard, seed: UInt64) {
        self.table = table
        self.rules = rules
        self.slots = table.format.slots
        self.rng = SeededRNG(seed: seed)
        self.pucks = Rink.faceoffPucks(on: table)
        self.mallets = slots.map { Mallet(position: table.malletZone(for: $0).center) }
        self.score = Rink.scoreOrder.map { _ in 0 }
        self.gamesWon = Rink.scoreOrder.map { _ in 0 }
        newMatch()
    }

    public func mallet(at slot: MalletSlot) -> Mallet? {
        slots.firstIndex(of: slot).map { mallets[$0] }
    }

    public func score(of side: Side) -> Int {
        score[Rink.tallyIndex(side)]
    }

    public func gamesWon(of side: Side) -> Int {
        gamesWon[Rink.tallyIndex(side)]
    }

    /// Start a fresh match: game score and games tally to zero, opening faceoff.
    /// The pucks sit frozen at center behind the force field until every mallet
    /// readies — no chance decides the opening, the players do by all grabbing
    /// in. The mallets stay where the hands left them.
    public mutating func newMatch() {
        score = Rink.scoreOrder.map { _ in 0 }
        gamesWon = Rink.scoreOrder.map { _ in 0 }
        pucks = Rink.faceoffPucks(on: table)
        phase = .opening
    }

    /// The faceoff arrangement: every puck frozen in a row at center, inside the
    /// force field, each wearing its table-given shape.
    static func faceoffPucks(on table: Playfield) -> [Puck] {
        let shapes = table.puckShapes
        let spacing = table.puckRadius * 2.6
        return shapes.indices.map { index in
            let offset = (Double(index) - Double(shapes.count - 1) / 2) * spacing
            return Puck(position: table.center + Vec2(offset, 0), shape: shapes[index])
        }
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
            // Play begins: a faceoff that followed a win clears the game score
            // now (the result stayed up until this moment); if that win ended the
            // whole match, the games tally clears too, for a fresh match.
            if let afterWin {
                score = Rink.scoreOrder.map { _ in 0 }
                if afterWin.endedMatch { gamesWon = Rink.scoreOrder.map { _ in 0 } }
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

    /// The result shown during a post-game faceoff (nil for the opening one, or
    /// during play): who won and whether it ended the match. Drives the
    /// WIN/LOSE and match overlays.
    public var lastOutcome: Outcome? {
        if case .faceoff(_, let afterWin) = phase { return afterWin }
        return nil
    }

    /// The winning side still shown during a post-game faceoff. Drives the
    /// WIN/LOSE overlay (game or match).
    public var finalWinner: Side? { lastOutcome?.winner }

    public var isFaceoff: Bool {
        if case .faceoff = phase { return true }
        return false
    }

    /// After a goal: the scored puck is served from center, gliding slowly into
    /// the conceder's half — any other pucks play on undisturbed. It moves AWAY
    /// from the far side — a puck heading into the conceder's own end is
    /// unreachable by the opponent until it settles.
    private mutating func serve(puckAt index: Int, to side: Side) {
        let towardOwnGoal = -side.inward
        pucks[index] = Puck(
            position: table.center, velocity: towardOwnGoal * table.serveSpeed,
            shape: pucks[index].shape)
    }

    /// One tick: every mallet moves (striking any puck on its way), then the
    /// pucks move. A finished game freezes only the pucks — the mallets are the
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
        // A puck may already be touching a resting mallet — but that is not a
        // NEW hit, so it emits no event; only a closing contact during a move does.
        if playing {
            stepPucks()
        }
    }

    /// A goal against `side` by the puck at `index`: that side concedes, the
    /// opposite side scores. The scored puck re-serves to the conceder while the
    /// rest play on — unless this point won the game, which freezes the table
    /// for the faceoff. Returns whether the game ended.
    mutating func goal(against side: Side, puckAt index: Int) -> Bool {
        let conceder = side
        let scorer = side.opponent
        score[Rink.tallyIndex(scorer)] += 1
        events.append(.goal(scorer: scorer, conceder: conceder))
        guard score(of: scorer) >= rules.pointsToWin else {
            serve(puckAt: index, to: rules.serveTo ?? conceder)
            return false
        }
        // The game is won: tally it, and decide whether that took the match.
        gamesWon[Rink.tallyIndex(scorer)] += 1
        let endedMatch = gamesWon(of: scorer) >= rules.gamesToWin
        // Show the result and open the faceoff; readying up starts the next game
        // (or, if the match ended, a fresh match — see `ready`).
        phase = .faceoff(ready: [], afterWin: Outcome(winner: scorer, endedMatch: endedMatch))
        pucks = Rink.faceoffPucks(on: table)
        events.append(endedMatch ? .matchOver(winner: scorer) : .gameWon(winner: scorer))
        return true
    }
}

extension Rink {
    /// Test seams: stage a puck or a mallet by hand. `internal`, reached via
    /// `@testable import`; nothing shipped calls them.
    /// Stages motion, not silhouette: the slot keeps the table's shape, so a
    /// test that set `puckShape` and then stages a position isn't silently
    /// handed a disc.
    mutating func setPuckForTesting(_ puck: Puck, at index: Int = 0) {
        pucks[index] = puck
        pucks[index].shape = table.puckShapes[index]
    }

    mutating func setMalletForTesting(_ mallet: Mallet, at slot: MalletSlot) {
        guard let index = slots.firstIndex(of: slot) else { return }
        mallets[index] = mallet
    }
}
