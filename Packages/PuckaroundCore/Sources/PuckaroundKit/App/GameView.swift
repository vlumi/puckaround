import PuckaroundCore
import SwiftUI

/// The table screen: one game of air hockey, plus the ways out of it — a dim
/// menu affordance during play (abandon / restart), and after a game both the
/// restart ring and a way back to the front door.
public struct GameView: View {
    @StateObject private var game: HockeyGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingPause = false

    let onExit: () -> Void

    public init(
        rules: Rules = .standard, puckShape: PuckShape = .circle,
        format: Format = .oneVsOne, sideWalls: SideWalls = .solid,
        onExit: @escaping () -> Void = {}
    ) {
        _game = StateObject(
            wrappedValue: HockeyGame(
                rules: rules, puckShape: puckShape, format: format, sideWalls: sideWalls))
        self.onExit = onExit
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Everything that reacts to the sim lives inside the timeline
                // closure, so it re-evaluates with the frame without publishing
                // anything. Layered, not stacked: the ZStack matters.
                TimelineView(.animation) { timeline in
                    let scene = game.frame(
                        at: timeline.date.timeIntervalSinceReferenceDate,
                        reducedMotion: reduceMotion)
                    ZStack {
                        Canvas { context, size in
                            RinkRenderer.draw(scene, in: &context, size: size)
                        }
                        InputSurface(game: game)
                        // ABOVE the input surface, or the multitouch view eats
                        // the taps.
                        overlay(for: scene)
                    }
                }
            }
            .onAppear {
                game.layout(screen: geo.size)
                game.begin()
                game.onMenuTap = { showingPause = true }
            }
            .onChangeCompat(of: geo.size) { size in game.layout(screen: size) }
            // The menu freezes the sim: the puck holds while it is open, and
            // resumes without a catch-up burst when it closes.
            .onChangeCompat(of: showingPause) { open in game.isPaused = open }
        }
        .background(RinkRenderer.ground.ignoresSafeArea())
        .statusBarHiddenIfAvailable()
        .persistentSystemOverlays(.hidden)
        .defersEdgeSwipes(true)
    }

    @ViewBuilder
    private func overlay(for scene: RinkScene) -> some View {
        if showingPause {
            pauseMenu
        }
        // The center ring IS the menu, but it is NOT a view on top of the table:
        // an overlapping tap view would swallow the touches that grab and drive a
        // mallet through the center. Instead a center-ring TAP is recognized
        // inside the multitouch input path (`HockeyGame.onMenuTap`), so a drag
        // through the ring stays ordinary play and only a tap opens the menu.
    }

    /// The menu behind the center ring: resume, restart, or quit to the front
    /// door. Restart scraps the current game for a fresh one — a new opening
    /// faceoff, score at zero, nobody readied — reachable from anywhere.
    private var pauseMenu: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { showingPause = false }
            VStack(spacing: 14) {
                NeonButton(title: "Resume", tint: Neon.cyan) { showingPause = false }
                NeonButton(title: "Restart") {
                    game.newGame()
                    showingPause = false
                }
                NeonButton(title: "Quit to menu", tint: Neon.magenta, action: onExit)
            }
            .frame(maxWidth: 260)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 18).fill(Neon.ground.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18).strokeBorder(Neon.inkSoft, lineWidth: 1))
            )
        }
    }
}
