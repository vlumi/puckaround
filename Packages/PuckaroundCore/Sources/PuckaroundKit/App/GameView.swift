import PuckaroundCore
import SwiftUI

/// The table screen: one game of air hockey, plus the ways out of it — the
/// center-ring pause menu (resume / restart / new match / quit). Its config
/// comes from a `Setup`, resolved against this game's `seed` so a "?" random
/// pick holds for the whole game.
struct GameView: View {
    @StateObject private var game: HockeyGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingPause = false
    @State private var showingNewMatch = false

    /// The setup the running game was built from — the New match modal opens on
    /// it, so the pickers show what's in play.
    let setup: Setup
    /// Commit a chosen setup and start a fresh match with it.
    let onNewMatch: (Setup) -> Void
    let onExit: () -> Void

    init(
        setup: Setup, seed: UInt64,
        onNewMatch: @escaping (Setup) -> Void, onExit: @escaping () -> Void
    ) {
        _game = StateObject(
            wrappedValue: HockeyGame(
                rules: setup.rules, puckShape: setup.resolvedPuck(roll: seed),
                format: setup.format, sideWalls: setup.resolvedWalls(roll: seed), seed: seed))
        self.setup = setup
        self.onNewMatch = onNewMatch
        self.onExit = onExit
    }

    var body: some View {
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
                        // the taps. The menus are ordinary SwiftUI and rotate with
                        // the interface, so they stay upright to the player.
                        overlay(for: scene)
                    }
                }
            }
            .onAppear {
                relayout(geo.size)
                game.begin()
                game.onMenuTap = { showingPause = true }
            }
            .onChangeCompat(of: geo.size) { size in relayout(size) }
            // The flips that keep the same size (left↔right landscape, portrait↔
            // upside-down) never change geo.size, so they get their own hook.
            .onDeviceOrientationChange { relayout(geo.size) }
            // Either overlay freezes the sim: the puck holds while a menu or the
            // modal is up, and resumes without a catch-up burst.
            .onChangeCompat(of: showingPause) { _ in syncPause() }
            .onChangeCompat(of: showingNewMatch) { _ in syncPause() }
        }
        .background(RinkRenderer.ground.ignoresSafeArea())
        .statusBarHiddenIfAvailable()
        .persistentSystemOverlays(.hidden)
        .defersEdgeSwipes(true)
    }

    @ViewBuilder
    private func overlay(for scene: RinkScene) -> some View {
        if showingNewMatch {
            NewMatchSheet(
                initial: setup,
                onStart: { chosen in
                    showingNewMatch = false
                    showingPause = false
                    onNewMatch(chosen)
                },
                onClose: { showingNewMatch = false })
        } else if showingPause {
            pauseMenu
        }
        // The center ring IS the menu, but it is NOT a view on top of the table:
        // an overlapping tap view would swallow the touches that grab and drive a
        // mallet through the center. Instead a center-ring TAP is recognized
        // inside the multitouch input path (`HockeyGame.onMenuTap`), so a drag
        // through the ring stays ordinary play and only a tap opens the menu.
    }

    /// The menu behind the center ring. Restart begins a fresh match with the
    /// same setup (re-rolling a "?" puck or walls); New match opens the modal to
    /// set up a different one. Both are reachable from anywhere.
    private var pauseMenu: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { showingPause = false }
            VStack(spacing: 14) {
                NeonButton(title: "Resume", tint: Neon.cyan) { showingPause = false }
                // Restart is "new match, same setup" — a fresh seed, so a "?"
                // puck or walls re-rolls (a match keeps its roll across its own
                // games; restarting is a new match, so it rolls again).
                NeonButton(title: "Restart") {
                    showingPause = false
                    onNewMatch(setup)
                }
                NeonButton(title: "New match…") { showingNewMatch = true }
                NeonButton(title: "Quit to title", tint: Neon.magenta, action: onExit)
            }
            .frame(maxWidth: 260)
            .padding(24)
            .background(NeonCard())
        }
    }

    /// Freeze the sim while either overlay is up, run it otherwise.
    private func syncPause() { game.isPaused = showingPause || showingNewMatch }

    /// Re-place the board for the current screen and physical device orientation.
    private func relayout(_ size: CGSize) {
        game.layout(screen: size, turnDegrees: InterfaceTurn.degrees)
    }
}
