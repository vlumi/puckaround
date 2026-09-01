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
    @AppStorage("puckaround.soundOn") private var soundOn = true
    @AppStorage("puckaround.hapticsOn") private var hapticsOn = true

    /// The setup the running game was built from — the New match modal opens on
    /// it, so the pickers show what's in play.
    let setup: Setup
    /// What kind of table this is — free, one tournament pairing, or practice.
    let mode: TableMode
    /// Commit a chosen setup and start a fresh match with it.
    let onNewMatch: (Setup) -> Void
    let onExit: () -> Void

    init(
        setup: Setup, seed: UInt64, mode: TableMode = .free,
        onNewMatch: @escaping (Setup) -> Void, onExit: @escaping () -> Void
    ) {
        _game = StateObject(
            wrappedValue: GameView.makeGame(setup: setup, seed: seed, mode: mode))
        self.setup = setup
        self.mode = mode
        self.onNewMatch = onNewMatch
        self.onExit = onExit
    }

    /// The table a mode plays on: the arcade brings its own canonical spec
    /// (scores must compare), everything else builds from the setup. In
    /// practice every serve comes to the human — a puck served into the
    /// machine's end would just wait on the sweep to send it back.
    private static func makeGame(setup: Setup, seed: UInt64, mode: TableMode) -> HockeyGame {
        if case .arcade(let spec) = mode {
            return HockeyGame(rules: spec.rules, table: spec.table, seed: seed, drive: .arcade)
        }
        var rules = setup.rules
        if mode.isPractice { rules.serveTo = .bottom }
        return HockeyGame(
            rules: rules,
            table: setup.resolvedTable(roll: seed, singles: mode.forcesSingles),
            seed: seed, drive: mode.isPractice ? .practice : .couch)
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
                game.setFeedback(sound: soundOn, haptics: hapticsOn)
                game.onMenuTap = { showingPause = true }
                game.endNames = mode.tournament?.names
                game.endColors = mode.tournament?.colors
                game.onMatchOver = mode.tournament?.onMatchOver
                game.onArcadeOver = mode.arcade?.onGameOver
            }
            .onChangeCompat(of: geo.size) { size in relayout(size) }
            // The flips that keep the same size (left↔right landscape, portrait↔
            // upside-down) never change geo.size, so they get their own hook.
            .onDeviceOrientationChange { relayout(geo.size) }
            // Either overlay freezes the sim: the puck holds while a menu or the
            // modal is up, and resumes without a catch-up burst.
            .onChangeCompat(of: showingPause) { _ in syncPause() }
            .onChangeCompat(of: showingNewMatch) { _ in syncPause() }
            .onChangeCompat(of: soundOn) { _ in
                game.setFeedback(sound: soundOn, haptics: hapticsOn)
            }
            .onChangeCompat(of: hapticsOn) { _ in
                game.setFeedback(sound: soundOn, haptics: hapticsOn)
            }
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
                initial: setup, practice: mode.isPractice,
                onStart: { chosen in
                    showingNewMatch = false
                    showingPause = false
                    onNewMatch(chosen)
                },
                onClose: { showingNewMatch = false })
        } else if showingPause {
            pauseMenu
        } else if let spec = mode.arcade, scene.rink.isFaceoff {
            // The attract screen IS the faceoff: the real table at full size,
            // the board floating over the machine's empty half, and grabbing
            // the mallet as the start button. It clears when the field drops.
            spec.attract
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
                if mode.allowsNewMatch {
                    NeonButton(title: mode.isPractice ? "New practice…" : "New match…") {
                        showingNewMatch = true
                    }
                }
                NeonButton(title: mode.exitTitle, tint: Neon.magenta, action: onExit)
                // Sound, as a quiet icon — rarely touched, but hushing a loud
                // table mid-game must be one tap away. Solid while sounding,
                // a hollow slash when hushed: the contrast is the state.
                NeonIconButton(
                    systemName: soundOn ? "speaker.wave.2" : "speaker.slash",
                    label: soundOn ? "Sound off" : "Sound on",
                    tint: Neon.ink, solid: soundOn
                ) {
                    soundOn.toggle()
                }
                .padding(.top, 2)
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

/// What a tournament adds to one match on the table: whose name is on each end,
/// and who to tell when the match is decided (winning side plus the two tallies
/// that decided it).
struct TournamentMatch {
    let names: EndNames
    /// The ends' clash-resolved kit colors — the table wears the players.
    let colors: EndColors
    let onMatchOver: (Side, Int, Int) -> Void
}

/// What the arcade adds to one table: the minigame's canonical spec — its
/// table and rules never come from the setup, or the board's scores wouldn't
/// compare — the attract content that floats on the table during the faceoff
/// (the board, and the pen after a boarding run), and who to tell when the
/// run ends (with the final score).
struct ArcadeTable {
    let table: Playfield
    let rules: Rules
    let attract: AnyView
    /// The run ended: its score, and the stage it died on (staged cabinets).
    let onGameOver: (Int, Int?) -> Void
}

/// What kind of table this is: a free match, one tournament pairing, practice
/// against the machine, or an arcade minigame.
enum TableMode {
    case free
    case tournament(TournamentMatch)
    case practice
    case arcade(ArcadeTable)

    var tournament: TournamentMatch? {
        if case .tournament(let match) = self { return match }
        return nil
    }

    var arcade: ArcadeTable? {
        if case .arcade(let spec) = self { return spec }
        return nil
    }

    /// Tournament pairings and practice both field one mallet per end. (The
    /// arcade never consults the setup at all.)
    var forcesSingles: Bool {
        if case .free = self { return false }
        return true
    }

    var isPractice: Bool {
        if case .practice = self { return true }
        return false
    }

    /// Whether the pause menu offers the setup modal — only tables built from
    /// the setup can be rebuilt from it.
    var allowsNewMatch: Bool { tournament == nil && arcade == nil }

    /// The pause menu's way out, named for who owns the table.
    var exitTitle: LocalizedStringKey {
        if tournament != nil { return "Back to tournament" }
        if arcade != nil { return "Quit to arcade" }
        return "Quit to title"
    }
}
