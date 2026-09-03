import PuckaroundCore
import SwiftUI

/// **One table of air hockey** (any format — 1v1, 1v2, 2v2). Owns the session,
/// the touch control source and the screen ↔ world mapping. Nothing here is
/// `@Published`: the view redraws every frame via `TimelineView(.animation)`
/// and reads the sim's phase and score from the frame it draws
/// (see `GameSession`).
@MainActor
final class HockeyGame: ObservableObject {
    private(set) var session: GameSession
    private(set) var controls: MalletControlSource
    private let sound = SoundEngine()
    private let haptics = Haptics()
    /// The tick the feedback layers have consumed events through, so a paused
    /// or replayed frame never fires the same hit twice.
    private var lastFedTick: Tick = -1
    /// How the board sits on screen — fit, rotation and coordinate mapping. The
    /// renderer draws through it and the touch mapping inverts it, so a finger
    /// lands where it looks in either orientation. Set by the view on layout.
    private(set) var placement = BoardPlacement(board: Vec2(1, 1), screen: .zero)

    /// In practice the machine drives the top end; nil otherwise.
    private let machine: PatternControlSource?
    /// The arcade's score-attack run riding this table; nil on a couch table.
    private(set) var arcade: ScoreAttack?
    /// Fired once when an arcade run ends, with the final score and — on a
    /// staged cabinet — the stage it died on.
    var onArcadeOver: ((Int, Int?) -> Void)?
    private var arcadeOverReported = false

    /// What drives the table besides fingers: nothing (the couch), the
    /// practice machine on the top end, or the arcade's score-attack loop.
    enum TableDrive {
        case couch
        case practice
        case arcade
    }

    init(
        rules: Rules = .standard, table: Playfield = .duel,
        seed: UInt64 = UInt64.random(in: 0...UInt64.max), drive: TableDrive = .couch
    ) {
        // The table's format sets each side's hand count; the zones follow it,
        // so they split into lanes wherever a side fields two.
        let rink = Rink(table: table, rules: rules, seed: seed)
        let controls = MalletControlSource(
            zones: SeatZones(format: table.format, bounds: table.bounds))
        self.controls = controls
        // The machine mans the far end in practice — and on survival tables,
        // which declare themselves by carrying a feeder.
        let machine =
            drive == .practice || table.feed != nil
            ? PatternControlSource(table: table) : nil
        self.machine = machine
        self.arcade = drive == .arcade ? ScoreAttack(survival: table.feed != nil) : nil
        self.session = GameSession(rink: rink) { slot, tick in
            if let machine, slot == machine.slot {
                return machine.input(for: slot, at: tick)
            }
            return controls.input(for: slot, at: tick)
        }
    }

    /// Freeze the sim (menu open) or let it run again. While paused the puck
    /// holds and drops any in-flight touches, so a finger left on a mallet
    /// doesn't fling it the instant play resumes.
    var isPaused: Bool {
        get { session.paused }
        set {
            session.paused = newValue
            if newValue { controls.releaseAll() }
        }
    }

    /// Start audio and warm the Taptic engine — called when the table appears.
    func begin() {
        sound.start()
        haptics.prepare()
    }

    /// Apply the user's feedback switches — sound can flip mid-game from the
    /// pause menu, both from Settings.
    func setFeedback(sound soundOn: Bool, haptics hapticsOn: Bool) {
        haptics.enabled = hapticsOn
        sound.enabled = soundOn
        if soundOn {
            sound.start()
        } else {
            sound.stop()
        }
    }

    // MARK: - Screen ↔ world

    func layout(screen: CGSize, turnDegrees: Double = 0) {
        placement = BoardPlacement(
            board: session.rink.table.size, screen: screen, turnDegrees: turnDegrees)
    }

    func world(fromScreen p: CGPoint) -> Vec2 {
        guard placement.scale > 0 else { return .zero }
        return placement.world(fromScreen: p)
    }

    /// Steps the sim to `time` and returns the frame to draw — plain values,
    /// because the Canvas renderer closure is not MainActor. `reducedMotion`
    /// comes from the view.
    func frame(at time: TimeInterval, reducedMotion: Bool) -> RinkScene {
        // The machine is always ready — only the human's grab starts play.
        if let machine, session.rink.isFaceoff,
            !session.rink.readyMallets.contains(machine.slot)
        {
            session.ready(machine.slot)
        }
        session.update(to: time)
        // Fire feedback for every tick actually stepped this frame. `events`
        // holds only the LATEST tick's, so a frame that stepped several would
        // drop the earlier ones' hits — but at 60 Hz a frame is one tick in the
        // common case, and the tick guard keeps a paused frame silent.
        if session.rink.tick != lastFedTick {
            lastFedTick = session.rink.tick
            consumeTick(at: time)
        }
        // A finished animation clears its anchor, so idle frames stop
        // re-deriving a done burst or beam forever after.
        if let start = faceoffBurstStart, time - start >= RinkScene.burstDuration {
            faceoffBurstStart = nil
        }
        if let start = beamStart, time - start.time >= RinkScene.beamDuration {
            beamStart = nil
        }
        let burst = faceoffBurstStart.map { (time - $0) / RinkScene.burstDuration }
        let beam = beamStart.map {
            BeamGhost(from: $0.from, progress: (time - $0.time) / RinkScene.beamDuration)
        }
        return RinkScene(
            rink: session.rink, placement: placement, reducedMotion: reducedMotion, time: time,
            faceoffBurst: burst, names: endNames, colors: endColors,
            arcade: arcade, beam: beam)
    }

    /// One freshly-stepped tick's consequences: feedback, the arcade run's
    /// bookkeeping, the animation anchors, and the deferred reports. Split
    /// from `frame(at:)` for the length limit; same per-tick contract.
    private func consumeTick(at time: TimeInterval) {
        haptics.play(session.rink.events)
        sound.play(session.rink.events)
        arcade?.ingest(session.rink.events)
        if session.rink.phase == .playing { arcade?.survive() }
        if let run = arcade, run.isOver, !arcadeOverReported {
            // The run is over: freeze the table under the final position
            // and tell the shelf once, off the view-evaluation stack.
            arcadeOverReported = true
            session.paused = true
            controls.releaseAll()
            let report = onArcadeOver
            let score = run.score
            let stage =
                session.rink.table.stages.isEmpty ? nil : session.rink.wallLevel + 1
            DispatchQueue.main.async { report?(score, stage) }
        }
        if session.rink.events.contains(.faceoffCleared) {
            faceoffBurstStart = time
        }
        for case .puckBeamed(let from) in session.rink.events {
            beamStart = (time, from)
        }
        for case .matchOver(let winner) in session.rink.events {
            let rink = session.rink
            let best = rink.rules.gamesToWin > 1
            let won = best ? rink.gamesWon(of: winner) : rink.score(of: winner)
            let lost =
                best
                ? rink.gamesWon(of: winner.opponent) : rink.score(of: winner.opponent)
            // Async: this runs inside view evaluation, where handlers must
            // not mutate SwiftUI state.
            let report = onMatchOver
            DispatchQueue.main.async { report?(winner, won, lost) }
        }
    }

    /// When the last faceoff cleared, so the burst ring can be animated from it.
    private var faceoffBurstStart: TimeInterval?
    /// When a rescue beam last fired, and from where — drives its animation.
    private var beamStart: (time: TimeInterval, from: Vec2)?

    // MARK: - Touches (screen points in, world points on)

    /// Opens the center-ring menu. The view sets this.
    var onMenuTap: (() -> Void)?

    /// The named ends during a tournament, or nil in a plain match. The view
    /// sets this; the renderer draws each name by its player's score.
    var endNames: EndNames?

    /// The ends' kit colors during a tournament — the players' own neons on
    /// mallet, goal, score and verdicts. Nil keeps the classic pair.
    var endColors: EndColors?

    /// Fired when the sim decides the match, with the winning side and the two
    /// tallies that decided it (games in a best-of, points in a single game) —
    /// the tournament records it and takes the table back. The view sets this.
    var onMatchOver: ((Side, Int, Int) -> Void)?

    /// Touches that began in the center ring and haven't moved yet — pending
    /// menu taps, one slot per finger so a second tap can't orphan the first.
    /// One only becomes the menu if it ends without moving; the moment it moves
    /// it is ordinary play (grab/drive a mallet), so a drag THROUGH the ring
    /// never gets stolen by the menu.
    private var pendingMenuTouches: [TouchID: CGPoint] = [:]
    /// How far a touch may drift and still count as a tap (screen points).
    private static let tapSlop: CGFloat = 10

    func touchBegan(id: TouchID, at p: CGPoint) {
        // A touch starting in the center ring is a candidate menu tap — held
        // back from the game until we know it's a tap, not the start of a drag.
        if hitsCenterRing(p) {
            pendingMenuTouches[id] = p
            return
        }
        startPlay(id: id, at: p)
    }

    func touchMoved(id: TouchID, at p: CGPoint) {
        if let start = pendingMenuTouches[id] {
            // Moved far enough to be a drag, not a tap: it's play after all —
            // hand it to the game from where it began, then continue.
            if hypot(p.x - start.x, p.y - start.y) > HockeyGame.tapSlop {
                pendingMenuTouches[id] = nil
                startPlay(id: id, at: start)
                let world = world(fromScreen: p)
                controls.touchMoved(id: id, at: world, malletAt: malletPosition(near: world))
            }
            return
        }
        let world = world(fromScreen: p)
        controls.touchMoved(id: id, at: world, malletAt: malletPosition(near: world))
    }

    func touchEnded(id: TouchID) {
        if pendingMenuTouches.removeValue(forKey: id) != nil {
            // Ended without moving: a tap on the center ring → open the menu.
            onMenuTap?()
            return
        }
        controls.touchEnded(id: id)
    }

    /// A touch the SYSTEM took away (a call, the app switcher) — never a tap,
    /// so a pending ring touch just clears instead of opening the menu the
    /// player didn't ask for; a play touch ends like any other.
    func touchCancelled(id: TouchID) {
        if pendingMenuTouches.removeValue(forKey: id) != nil { return }
        controls.touchEnded(id: id)
    }

    /// Begin an ordinary play touch: grab/drive a mallet if the finger is near
    /// it, and — during a faceoff — ready that side's mallet, since reaching for
    /// it is declaring ready (readying stays lenient; the grab itself doesn't).
    private func startPlay(id: TouchID, at p: CGPoint) {
        let world = world(fromScreen: p)
        if session.rink.isFaceoff, let slot = controls.zones.owner(of: world) {
            session.ready(slot)
        }
        controls.touchBegan(id: id, at: world, malletAt: malletPosition(near: world))
    }

    /// Where the mallet a touch at `world` would drive currently sits — the
    /// mallet owning that point's zone (the finger's own position on an empty
    /// half, so nothing grabs). The control source uses it to decide whether
    /// the finger is close enough to grab.
    private func malletPosition(near world: Vec2) -> Vec2 {
        guard let slot = controls.zones.owner(of: world) else { return world }
        return session.rink.mallet(at: slot)?.position ?? world
    }

    /// Whether a screen point lands within the center-ring menu button. Tested in
    /// world units (against the table center), so it holds in either orientation.
    private func hitsCenterRing(_ p: CGPoint) -> Bool {
        guard placement.scale > 0 else { return false }
        let w = world(fromScreen: p)
        let c = session.rink.table.center
        return hypot(w.x - c.x, w.y - c.y) <= RinkRenderer.centerRingRadius
    }
}
