import PuckaroundCore
import SwiftUI

/// **The v0.1 table: one puck, one rink, 2–4 seats, and nothing to win.** The
/// place the strike model and the table's feel get proven before a game is
/// built on them; a real front door replaces the HUD buttons later.
///
/// Owns the session, the touch control source and the screen ↔ world mapping.
/// Only the lineup is `@Published` — per-frame state is read by the redraw,
/// never published (see `GameSession`).
@MainActor
public final class Sandbox: ObservableObject {
    @Published public private(set) var lineup: Lineup
    public private(set) var session: GameSession
    public private(set) var controls: SwipeControlSource
    /// Where the table sits on screen; set by the view on layout.
    private(set) var tableRect = CGRect.zero

    public init(lineup: Lineup = .duel, seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        self.lineup = lineup
        (session, controls) = Sandbox.build(lineup: lineup, seed: seed)
    }

    private static func build(lineup: Lineup, seed: UInt64) -> (GameSession, SwipeControlSource) {
        let table = Playfield.standard(for: lineup)
        let rink = Rink(table: table, lineup: lineup, seed: seed)
        let controls = SwipeControlSource(zones: SeatZones(lineup: lineup, bounds: table.bounds))
        let session = GameSession(rink: rink) { player, tick in
            controls.input(for: player, at: tick)
        }
        return (session, controls)
    }

    /// A new table for a new lineup — fresh seed, every finger released.
    public func setLineup(_ lineup: Lineup) {
        controls.releaseAll()
        self.lineup = lineup
        (session, controls) = Sandbox.build(lineup: lineup, seed: UInt64.random(in: 0...UInt64.max))
    }

    /// 2 → 3 → 4 → 2, always as a free-for-all.
    public func cyclePlayers() {
        let next = lineup.playerCount % Lineup.maxPlayers + 1
        let count = max(Lineup.minPlayers, next)
        if let lineup = Lineup(playerCount: count) {
            setLineup(lineup)
        }
    }

    public func toggleTeams() {
        if let lineup = Lineup(playerCount: lineup.playerCount, teamed: !lineup.teamed) {
            setLineup(lineup)
        }
    }

    public func serve() {
        session.serve()
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
    func frame(at time: TimeInterval) -> RinkScene {
        session.update(to: time)
        return RinkScene(rink: session.rink, tableRect: tableRect)
    }

    // MARK: - Touches (screen points in, world points on)

    func touchBegan(id: TouchID, at p: CGPoint, time: Double) {
        controls.touchBegan(id: id, at: world(fromScreen: p), time: time)
    }

    func touchMoved(id: TouchID, at p: CGPoint, time: Double) {
        controls.touchMoved(id: id, at: world(fromScreen: p), time: time)
    }

    func touchEnded(id: TouchID) {
        controls.touchEnded(id: id)
    }
}
