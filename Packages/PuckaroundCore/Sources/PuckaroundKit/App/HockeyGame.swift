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

    init(
        rules: Rules = .standard, puckShape: PuckShape = .circle,
        format: Format = .oneVsOne, sideWalls: SideWalls = .solid,
        seed: UInt64 = UInt64.random(in: 0...UInt64.max)
    ) {
        // The chosen format sets each side's hand count; the zones follow the
        // table's own format, so they split into lanes wherever a side fields two.
        var table = Playfield.duel.with(format: format)
        table.puckShape = puckShape
        table.sideWalls = sideWalls
        let rink = Rink(table: table, rules: rules, seed: seed)
        let controls = MalletControlSource(
            zones: SeatZones(format: table.format, bounds: table.bounds))
        self.controls = controls
        self.session = GameSession(rink: rink) { slot, tick in
            controls.input(for: slot, at: tick)
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
        session.update(to: time)
        // Fire feedback for every tick actually stepped this frame. `events`
        // holds only the LATEST tick's, so a frame that stepped several would
        // drop the earlier ones' hits — but at 60 Hz a frame is one tick in the
        // common case, and the tick guard keeps a paused frame silent.
        if session.rink.tick != lastFedTick {
            haptics.play(session.rink.events)
            sound.play(session.rink.events)
            lastFedTick = session.rink.tick
            if session.rink.events.contains(.faceoffCleared) {
                faceoffBurstStart = time  // the field bursts — kick off the visual
            }
            for case .matchOver(let winner) in session.rink.events {
                let rink = session.rink
                let best = rink.rules.gamesToWin > 1
                let won = best ? rink.gamesWon(of: winner) : rink.score(of: winner)
                let lost =
                    best
                    ? rink.gamesWon(of: winner.opponent) : rink.score(of: winner.opponent)
                // Async: frame(at:) runs inside view evaluation, where handlers
                // must not mutate SwiftUI state.
                let report = onMatchOver
                DispatchQueue.main.async { report?(winner, won, lost) }
            }
        }
        let burst = faceoffBurstStart.map { min(1, (time - $0) / RinkScene.burstDuration) }
        return RinkScene(
            rink: session.rink, placement: placement, reducedMotion: reducedMotion, time: time,
            faceoffBurst: (burst ?? 1) < 1 ? burst : nil, names: endNames)
    }

    /// When the last faceoff cleared, so the burst ring can be animated from it.
    private var faceoffBurstStart: TimeInterval?

    // MARK: - Touches (screen points in, world points on)

    /// Opens the center-ring menu. The view sets this.
    var onMenuTap: (() -> Void)?

    /// The named ends during a tournament, or nil in a plain match. The view
    /// sets this; the renderer draws each name by its player's score.
    var endNames: EndNames?

    /// Fired when the sim decides the match, with the winning side and the two
    /// tallies that decided it (games in a best-of, points in a single game) —
    /// the tournament records it and takes the table back. The view sets this.
    var onMatchOver: ((Side, Int, Int) -> Void)?

    /// A touch that began in the center ring and hasn't moved yet — a pending
    /// menu tap. It only becomes the menu if it ends without moving; the moment
    /// it moves it is ordinary play (grab/drive a mallet), so a drag THROUGH the
    /// ring never gets stolen by the menu.
    private var pendingMenuTouch: (id: TouchID, at: CGPoint)?
    /// How far a touch may drift and still count as a tap (screen points).
    private static let tapSlop: CGFloat = 10

    func touchBegan(id: TouchID, at p: CGPoint) {
        // A touch starting in the center ring is a candidate menu tap — held
        // back from the game until we know it's a tap, not the start of a drag.
        if hitsCenterRing(p) {
            pendingMenuTouch = (id, p)
            return
        }
        startPlay(id: id, at: p)
    }

    func touchMoved(id: TouchID, at p: CGPoint) {
        if let pending = pendingMenuTouch, pending.id == id {
            // Moved far enough to be a drag, not a tap: it's play after all —
            // hand it to the game from where it began, then continue.
            if hypot(p.x - pending.at.x, p.y - pending.at.y) > HockeyGame.tapSlop {
                pendingMenuTouch = nil
                startPlay(id: id, at: pending.at)
                let world = world(fromScreen: p)
                controls.touchMoved(id: id, at: world, malletAt: malletPosition(near: world))
            }
            return
        }
        let world = world(fromScreen: p)
        controls.touchMoved(id: id, at: world, malletAt: malletPosition(near: world))
    }

    func touchEnded(id: TouchID) {
        if let pending = pendingMenuTouch, pending.id == id {
            // Ended without moving: a tap on the center ring → open the menu.
            pendingMenuTouch = nil
            onMenuTap?()
            return
        }
        controls.touchEnded(id: id)
    }

    /// Begin an ordinary play touch: grab/drive a mallet if the finger is near
    /// it, and — during a faceoff — ready that side's mallet, since reaching for
    /// it is declaring ready (readying stays lenient; the grab itself doesn't).
    private func startPlay(id: TouchID, at p: CGPoint) {
        let world = world(fromScreen: p)
        if session.rink.isFaceoff {
            session.ready(controls.zones.owner(of: world))
        }
        controls.touchBegan(id: id, at: world, malletAt: malletPosition(near: world))
    }

    /// Where the mallet a touch at `world` would drive currently sits — the
    /// mallet owning that point's zone. The control source uses it to decide
    /// whether the finger is close enough to grab.
    private func malletPosition(near world: Vec2) -> Vec2 {
        let slot = controls.zones.owner(of: world)
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
