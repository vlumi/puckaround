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

    public init(rules: Rules = .standard, onExit: @escaping () -> Void = {}) {
        _game = StateObject(wrappedValue: HockeyGame(rules: rules))
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
            }
            .onChangeCompat(of: geo.size) { size in game.layout(screen: size) }
        }
        .background(RinkRenderer.ground.ignoresSafeArea())
        .statusBarHiddenIfAvailable()
        .persistentSystemOverlays(.hidden)
        .defersEdgeSwipes(true)
    }

    @ViewBuilder
    private func overlay(for scene: RinkScene) -> some View {
        let rect = scene.tableRect
        if showingPause {
            pauseMenu
        } else {
            // The centre ring IS the menu — always, whether playing or between
            // games. The tap target matches the drawn ring (see the renderer's
            // centre-ring radius), on the neutral centre spot under the puck, so
            // it belongs to neither player.
            let diameter =
                2 * RinkRenderer.centreRingRadius * (rect.width / scene.rink.table.size.x)
            Circle()
                .fill(Color.white.opacity(0.001))
                .frame(width: diameter, height: diameter)
                .position(x: rect.midX, y: rect.midY)
                .onTapGesture { showingPause = true }
                .accessibilityLabel(Text("Menu", bundle: .module))
        }
    }

    /// The menu behind the centre ring: resume, restart, or quit to the front
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
