import PuckaroundCore
import SwiftUI

/// **One table of 1v1 air hockey.** Owns the session, the touch control source
/// and the screen ↔ world mapping. Nothing here is `@Published`: the view
/// redraws every frame via `TimelineView(.animation)` and reads the sim's
/// phase and score from the frame it draws (see `GameSession`).
@MainActor
public final class HockeyGame: ObservableObject {
    public let lineup = Lineup.duel
    public private(set) var session: GameSession
    public private(set) var controls: MalletControlSource
    /// Where the table sits on screen; set by the view on layout.
    private(set) var tableRect = CGRect.zero

    public init(seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        let table = Playfield.duel
        let rink = Rink(table: table, lineup: lineup, seed: seed)
        let controls = MalletControlSource(zones: SeatZones(lineup: lineup, bounds: table.bounds))
        self.controls = controls
        self.session = GameSession(rink: rink) { player, tick in
            controls.input(for: player, at: tick)
        }
    }

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
    func frame(at time: TimeInterval) -> RinkScene {
        session.update(to: time)
        return RinkScene(rink: session.rink, tableRect: tableRect)
    }

    // MARK: - Touches (screen points in, world points on)

    func touchBegan(id: TouchID, at p: CGPoint) {
        controls.touchBegan(id: id, at: world(fromScreen: p))
    }

    func touchMoved(id: TouchID, at p: CGPoint) {
        controls.touchMoved(id: id, at: world(fromScreen: p))
    }

    func touchEnded(id: TouchID) {
        controls.touchEnded(id: id)
    }
}
