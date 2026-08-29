import PuckaroundCore
import SwiftUI

/// **One table of 1v1 air hockey.** Owns the session, the touch control source
/// and the screen ↔ world mapping. Nothing here is `@Published`: the view
/// redraws every frame via `TimelineView(.animation)` and reads the sim's
/// phase and score from the frame it draws (see `GameSession`).
@MainActor
public final class HockeyGame: ObservableObject {
    public private(set) var session: GameSession
    public private(set) var controls: MalletControlSource
    private let sound = SoundEngine()
    private let haptics = Haptics()
    /// The tick the feedback layers have consumed events through, so a paused
    /// or replayed frame never fires the same hit twice.
    private var lastFedTick: Tick = -1
    /// Where the table sits on screen; set by the view on layout.
    private(set) var tableRect = CGRect.zero

    /// Sound and haptics on? Both default on; the front door will expose them.
    public var feedbackEnabled = true {
        didSet {
            sound.enabled = feedbackEnabled
            haptics.enabled = feedbackEnabled
            if feedbackEnabled {
                sound.start()
            } else {
                sound.stop()
            }
        }
    }

    public let rules: Rules

    public init(
        rules: Rules = .standard, puckShape: PuckShape = .circle,
        seed: UInt64 = UInt64.random(in: 0...UInt64.max)
    ) {
        self.rules = rules
        // Singles by default — `Playfield.duel` carries `.oneVsOne`; a format
        // picker is a later task. The zones follow the table's own format.
        var table = Playfield.duel
        table.puckShape = puckShape
        let rink = Rink(table: table, rules: rules, seed: seed)
        let controls = MalletControlSource(
            zones: SeatZones(format: table.format, bounds: table.bounds))
        self.controls = controls
        self.session = GameSession(rink: rink) { slot, tick in
            controls.input(for: slot, at: tick)
        }
    }

    /// Start audio and warm the Taptic engine — called when the table appears.
    public func begin() {
        sound.start()
        haptics.prepare()
    }

    /// Start over — same players, same rules, a fresh faceoff. Used by the
    /// restart ring after a game, and by "restart" mid-game.
    public func newGame() {
        controls.releaseAll()
        session.newGame()
    }

    // MARK: - Screen ↔ world

    func layout(screen: CGSize) {
        tableRect = RinkRenderer.fittedTableRect(tableSize: session.rink.table.size, in: screen)
    }

    func world(fromScreen p: CGPoint) -> Vec2 {
        guard tableRect.width > 0 else { return .zero }
        let scale = session.rink.table.size.x / tableRect.width
        return Vec2((p.x - tableRect.minX) * scale, (p.y - tableRect.minY) * scale)
    }

    /// Steps the sim to `time` and returns the frame to draw — plain values,
    /// because the Canvas renderer closure is not MainActor.
    /// `reducedMotion` comes from the environment; the view passes it in.
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
        }
        let burst = faceoffBurstStart.map { min(1, (time - $0) / RinkScene.burstDuration) }
        return RinkScene(
            rink: session.rink, tableRect: tableRect, reducedMotion: reducedMotion, time: time,
            faceoffBurst: (burst ?? 1) < 1 ? burst : nil)
    }

    /// When the last faceoff cleared, so the burst ring can be animated from it.
    private var faceoffBurstStart: TimeInterval?

    // MARK: - Touches (screen points in, world points on)

    /// Opens the centre-ring menu. The view sets this.
    var onMenuTap: (() -> Void)?

    /// A touch that began in the centre ring and hasn't moved yet — a pending
    /// menu tap. It only becomes the menu if it ends without moving; the moment
    /// it moves it is ordinary play (grab/drive a mallet), so a drag THROUGH the
    /// ring never gets stolen by the menu.
    private var pendingMenuTouch: (id: TouchID, at: CGPoint)?
    /// How far a touch may drift and still count as a tap (screen points).
    private static let tapSlop: CGFloat = 10

    func touchBegan(id: TouchID, at p: CGPoint) {
        // A touch starting in the centre ring is a candidate menu tap — held
        // back from the game until we know it's a tap, not the start of a drag.
        if hitsCentreRing(p) {
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
                controls.touchMoved(id: id, at: world(fromScreen: p))
            }
            return
        }
        controls.touchMoved(id: id, at: world(fromScreen: p))
    }

    func touchEnded(id: TouchID) {
        if let pending = pendingMenuTouch, pending.id == id {
            // Ended without moving: a tap on the centre ring → open the menu.
            pendingMenuTouch = nil
            onMenuTap?()
            return
        }
        controls.touchEnded(id: id)
    }

    /// Begin an ordinary play touch: grab/drive a mallet, and — during a faceoff
    /// — ready that mallet, since grabbing it IS declaring ready.
    private func startPlay(id: TouchID, at p: CGPoint) {
        let world = world(fromScreen: p)
        if session.rink.isFaceoff {
            session.ready(controls.zones.owner(of: world))
        }
        controls.touchBegan(id: id, at: world)
    }

    /// Whether a screen point lands within the centre-ring menu button.
    private func hitsCentreRing(_ p: CGPoint) -> Bool {
        guard tableRect.width > 0 else { return false }
        let scale = tableRect.width / session.rink.table.size.x
        let radius = RinkRenderer.centreRingRadius * scale
        return hypot(p.x - tableRect.midX, p.y - tableRect.midY) <= radius
    }
}
