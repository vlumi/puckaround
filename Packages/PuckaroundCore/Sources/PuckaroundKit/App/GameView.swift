import PuckaroundCore
import SwiftUI

/// The table screen: one game of air hockey, plus the ways out of it — a dim
/// menu affordance during play (settings / restart / quit). Its config comes
/// from the shared `GameSettings`, resolved against this game's `seed` so a "?"
/// random pick holds for the whole game.
struct GameView: View {
    @StateObject private var game: HockeyGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingPause = false
    @State private var showingSettings = false
    /// The sheet's working copy — edited freely and only committed on confirm, so
    /// Cancel can discard it and leave the running game (and stored setup) alone.
    @State private var draft = Setup()

    /// The setup the running game was built from — the draft is diffed against it
    /// to decide whether confirming restarts or just resumes.
    let setup: Setup
    /// Commit a changed setup: the caller stores it and starts a fresh game.
    let onNewGame: (Setup) -> Void
    let onExit: () -> Void

    init(
        setup: Setup, seed: UInt64,
        onNewGame: @escaping (Setup) -> Void = { _ in }, onExit: @escaping () -> Void = {}
    ) {
        _game = StateObject(
            wrappedValue: HockeyGame(
                rules: setup.rules, puckShape: setup.resolvedPuck(roll: seed),
                format: setup.format, sideWalls: setup.resolvedWalls(roll: seed), seed: seed))
        self.setup = setup
        self.onNewGame = onNewGame
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
            // Either overlay freezes the sim: the puck holds while a menu or the
            // settings sheet is up, and resumes without a catch-up burst.
            .onChangeCompat(of: showingPause) { _ in syncPause() }
            .onChangeCompat(of: showingSettings) { _ in syncPause() }
        }
        .background(RinkRenderer.ground.ignoresSafeArea())
        .statusBarHiddenIfAvailable()
        .persistentSystemOverlays(.hidden)
        .defersEdgeSwipes(true)
    }

    @ViewBuilder
    private func overlay(for scene: RinkScene) -> some View {
        if showingSettings {
            settingsSheet
        } else if showingPause {
            pauseMenu
        }
        // The center ring IS the menu, but it is NOT a view on top of the table:
        // an overlapping tap view would swallow the touches that grab and drive a
        // mallet through the center. Instead a center-ring TAP is recognized
        // inside the multitouch input path (`HockeyGame.onMenuTap`), so a drag
        // through the ring stays ordinary play and only a tap opens the menu.
    }

    /// The menu behind the center ring: change the setup, restart, or quit to the
    /// front door. Restart scraps the current game for a fresh one — a new opening
    /// faceoff, score at zero, nobody readied — reachable from anywhere.
    private var pauseMenu: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { showingPause = false }
            VStack(spacing: 14) {
                NeonButton(title: "Resume", tint: Neon.cyan) { showingPause = false }
                NeonButton(title: "Change setup") {
                    draft = setup
                    showingSettings = true
                }
                NeonButton(title: "Restart") {
                    game.newGame()
                    showingPause = false
                }
                NeonButton(title: "Quit to menu", tint: Neon.magenta, action: onExit)
            }
            .frame(maxWidth: 260)
            .padding(24)
            .background(menuCard)
        }
    }

    /// The setup pickers on a solid card over the table. Edits go to `draft`, so
    /// Cancel discards them and the running game plays on. The confirm button
    /// says what it will do: with a change it starts a fresh game (the only way
    /// to swap puck, format, length or walls mid-match), otherwise it just
    /// resumes — never a silent restart.
    private var settingsSheet: some View {
        let changed = draft != setup
        return ZStack {
            Color.black.opacity(0.85).ignoresSafeArea().onTapGesture { cancelSettings() }
            ScrollView {
                VStack(spacing: 24) {
                    SetupControls(setup: $draft)
                    // A change means starting over — the note makes that plain
                    // before the button confirms it.
                    if changed {
                        Text("Changing the setup starts a new game.", bundle: .module)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Neon.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    HStack(spacing: 12) {
                        NeonButton(title: "Cancel", tint: Neon.magenta) { cancelSettings() }
                        NeonButton(
                            title: changed ? "Start new game" : "Resume", tint: Neon.cyan,
                            prominent: true
                        ) {
                            confirmSettings(changed: changed)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 440)
                .background(menuCard)
                .padding(16)
            }
        }
    }

    /// Discard the draft and return to the paused table where we left it.
    private func cancelSettings() {
        showingSettings = false
        showingPause = false
    }

    /// Apply the draft: start a fresh game if it changed anything, otherwise just
    /// resume — the confirm button's label already told the player which.
    private func confirmSettings(changed: Bool) {
        showingSettings = false
        showingPause = false
        if changed { onNewGame(draft) }
    }

    /// Freeze the sim while either overlay is up, run it otherwise.
    private func syncPause() { game.isPaused = showingPause || showingSettings }

    private var menuCard: some View {
        RoundedRectangle(cornerRadius: 18).fill(Neon.ground.opacity(0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 18).strokeBorder(Neon.inkSoft, lineWidth: 1))
    }
}
