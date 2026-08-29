import PuckaroundCore
import SwiftUI

/// The whole app's top level: the front door, or a table. Owns the one setting
/// that exists (goals to win) and swaps between the menu and a fresh game.
public struct AppRoot: View {
    @State private var phase: Phase = .menu
    @AppStorage("puckaround.pointsToWin") private var pointsToWin = 7
    @AppStorage("puckaround.puckShape") private var puckShapeKey = PuckShapeKey.circle.rawValue
    /// Hands per side, 1 or 2 — the format, stored as two Ints because `Format`
    /// isn't a raw-representable `@AppStorage` value. Both default to singles.
    @AppStorage("puckaround.bottomHands") private var bottomHands = 1
    @AppStorage("puckaround.topHands") private var topHands = 1

    private enum Phase {
        case menu
        /// A live game. Identified so swapping games replaces the view cleanly.
        case playing(id: UUID)
    }

    public init() {}

    public var body: some View {
        switch phase {
        case .menu:
            MenuView(
                pointsToWin: $pointsToWin,
                puckShapeKey: $puckShapeKey,
                bottomHands: $bottomHands,
                topHands: $topHands,
                onPlay: { phase = .playing(id: UUID()) })
        case .playing(let id):
            GameView(
                rules: Rules(pointsToWin: pointsToWin),
                puckShape: PuckShapeKey(rawValue: puckShapeKey)?.shape ?? .circle,
                format: format,
                onExit: { phase = .menu }
            )
            // Keyed so "restart" (a new game id) tears down the old table
            // and its session/sound cleanly rather than reusing them.
            .id(id)
        }
    }

    /// The stored per-side hand counts as a `Format` (anything but 1 or 2 falls
    /// back to one hand, so a stale or bad stored value can't crash the table).
    private var format: Format {
        Format(bottom: bottomHands == 2 ? .two : .one, top: topHands == 2 ? .two : .one)
    }
}
