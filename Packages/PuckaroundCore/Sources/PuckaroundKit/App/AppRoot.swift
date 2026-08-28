import PuckaroundCore
import SwiftUI

/// The whole app's top level: the front door, or a table. Owns the one setting
/// that exists (goals to win) and swaps between the menu and a fresh game.
public struct AppRoot: View {
    @State private var phase: Phase = .menu
    @AppStorage("puckaround.pointsToWin") private var pointsToWin = 7

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
                onPlay: { phase = .playing(id: UUID()) })
        case .playing(let id):
            GameView(
                rules: Rules(pointsToWin: pointsToWin),
                onExit: { phase = .menu }
            )
            // Keyed so "restart" (a new game id) tears down the old table
            // and its session/sound cleanly rather than reusing them.
            .id(id)
        }
    }
}
