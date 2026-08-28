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
        if case .finished = scene.rink.phase {
            finishControls(at: CGPoint(x: scene.tableRect.midX, y: scene.tableRect.midY))
        } else if showingPause {
            pauseMenu
        } else {
            // The dim way in: a small menu dot on the centre line, out of the
            // thumbs' way. Tapping it pauses to the abandon/restart choice.
            NeonIconButton(systemName: "pause.fill", label: "Menu") {
                showingPause = true
            }
            .position(x: scene.tableRect.midX, y: scene.tableRect.midY)
        }
    }

    /// A game in progress can be abandoned or restarted — both destructive, so
    /// they sit behind the pause dot rather than on the table.
    private var pauseMenu: some View {
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
            RoundedRectangle(cornerRadius: 18).fill(Neon.ground.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18).strokeBorder(Neon.inkSoft, lineWidth: 1)))
    }

    /// After a game: restart it (the ring, symmetric so it reads from both
    /// ends), or go back to the front door.
    private func finishControls(at centre: CGPoint) -> some View {
        VStack(spacing: 16) {
            restartRing
            NeonButton(title: "Menu", tint: Neon.inkSoft) { onExit() }
                .frame(width: 150)
        }
        .position(centre)
    }

    private var restartRing: some View {
        Button {
            game.newGame()
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(RinkRenderer.line)
                .shadow(color: RinkRenderer.line.opacity(0.8), radius: 8)
                .frame(width: 78, height: 78)
                .background(
                    Circle().fill(RinkRenderer.ice.opacity(0.9))
                        .overlay(
                            Circle().strokeBorder(RinkRenderer.line, lineWidth: 2)
                                .shadow(color: RinkRenderer.line.opacity(0.7), radius: 6)))
        }
        .accessibilityLabel(Text("New game", bundle: .module))
    }
}
