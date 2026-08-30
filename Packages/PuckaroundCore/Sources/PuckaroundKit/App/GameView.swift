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
    /// The setup as it was when the settings sheet opened, so closing it can tell
    /// whether anything actually changed — a change restarts, a no-op resumes.
    @State private var settingsSnapshot: Fingerprint?

    let settings: GameSettings
    let onRestart: () -> Void
    let onExit: () -> Void

    init(
        settings: GameSettings, seed: UInt64,
        onRestart: @escaping () -> Void = {}, onExit: @escaping () -> Void = {}
    ) {
        _game = StateObject(
            wrappedValue: HockeyGame(
                rules: settings.rules, puckShape: settings.resolvedPuck(roll: seed),
                format: settings.format, sideWalls: settings.resolvedWalls(roll: seed), seed: seed))
        self.settings = settings
        self.onRestart = onRestart
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
                NeonButton(title: "Settings") {
                    settingsSnapshot = Fingerprint(settings)
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

    /// The setup pickers over the table. Closing it starts a fresh game with the
    /// new setup if anything changed (the only way to swap puck, format or walls
    /// mid-match without a trip back to the title), or just resumes if not.
    private var settingsSheet: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { closeSettings() }
            ScrollView {
                VStack(spacing: 24) {
                    SetupControls(settings: settings)
                    NeonButton(title: "Done", tint: Neon.cyan, prominent: true) { closeSettings() }
                }
                .padding(24)
                .frame(maxWidth: 440)
            }
        }
    }

    /// Close the settings sheet: restart into a fresh game if the setup changed,
    /// otherwise drop back to the paused table where we left it.
    private func closeSettings() {
        showingSettings = false
        showingPause = false
        if settingsSnapshot != Fingerprint(settings) {
            onRestart()
        }
    }

    /// Freeze the sim while either overlay is up, run it otherwise.
    private func syncPause() { game.isPaused = showingPause || showingSettings }

    private var menuCard: some View {
        RoundedRectangle(cornerRadius: 18).fill(Neon.ground.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 18).strokeBorder(Neon.inkSoft, lineWidth: 1))
    }
}

/// A snapshot of the setup values that decide the table — enough to tell whether
/// closing the settings sheet must restart the game. (`randomPuck`/`randomWalls`
/// count: turning "?" on or off changes the table even at the same stored pick.)
private struct Fingerprint: Equatable {
    let points: Int
    let games: Int
    let puck: String
    let randomPuck: Bool
    let bottom: Int
    let top: Int
    let wrap: Bool
    let randomWalls: Bool

    init(_ s: GameSettings) {
        points = s.pointsToWin
        games = s.gamesToWin
        puck = s.puckShapeKey
        randomPuck = s.randomPuck
        bottom = s.bottomHands
        top = s.topHands
        wrap = s.wrapWalls
        randomWalls = s.randomWalls
    }
}
