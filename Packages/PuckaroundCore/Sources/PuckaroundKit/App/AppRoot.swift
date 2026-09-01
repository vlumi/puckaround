import PuckaroundCore
import SwiftUI

/// The whole app's top level: the front door, or a table. Owns the stored setup
/// (`@AppStorage`, one field each) and swaps between the menu and a fresh game.
/// A game is identified by a seed that also drives any "?" random pick, so the
/// picked puck and walls hold for that game and re-roll on the next.
public struct AppRoot: View {
    @State private var phase: Phase = .menu
    @AppStorage("puckaround.pointsToWin") private var pointsToWin = 7
    /// Games to win the match — 1 is a single game (the default).
    @AppStorage("puckaround.gamesToWin") private var gamesToWin = 1
    @AppStorage("puckaround.puckShape") private var puckShapeKey = PuckShapeKey.circle.rawValue
    /// "?" for the puck — roll a shape each game instead of a fixed one.
    @AppStorage("puckaround.randomPuck") private var randomPuck = false
    /// How many pucks fly at once (1–3).
    @AppStorage("puckaround.puckCount") private var puckCount = 1
    /// "?" for the count — roll 1–3 each game.
    @AppStorage("puckaround.randomPuckCount") private var randomPuckCount = false
    /// Hands per side, 1 or 2 — the format, stored as two Ints because `Format`
    /// isn't a raw-representable `@AppStorage` value. Both default to singles.
    @AppStorage("puckaround.bottomHands") private var bottomHands = 1
    @AppStorage("puckaround.topHands") private var topHands = 1
    /// Whether the long side walls wrap (portals) instead of bouncing.
    @AppStorage("puckaround.wrapWalls") private var wrapWalls = false
    /// "?" for the walls — flip solid/wrap each game.
    @AppStorage("puckaround.randomWalls") private var randomWalls = false

    private enum Phase {
        case menu
        /// A live game, keyed by its seed so swapping games (restart, or a
        /// mid-game settings change) replaces the view and re-rolls "?" cleanly.
        case playing(seed: UInt64)
        /// The tournament flow — roster, interstitials and its own matches.
        case tournament
        /// Practice against the machine, keyed like a game.
        case practice(seed: UInt64)
        /// The arcade shelf — solo minigames and their boards.
        case arcade
    }

    public init() {}

    public var body: some View {
        switch phase {
        case .menu:
            MenuView(
                setup: setupBinding, onPlay: { phase = .playing(seed: freshSeed()) },
                onTournament: { phase = .tournament },
                onPractice: { phase = .practice(seed: freshSeed()) },
                onArcade: { phase = .arcade })
        case .playing(let seed):
            GameView(
                setup: setup, seed: seed,
                onNewMatch: { newSetup in
                    apply(newSetup)
                    phase = .playing(seed: freshSeed())
                },
                onExit: { phase = .menu }
            )
            // Keyed on the seed so "restart" (and a settings change that re-rolls
            // it) tears down the old table and its session/sound cleanly.
            .id(seed)
        case .tournament:
            TournamentView(setup: setupBinding, onExit: { phase = .menu })
        case .practice(let seed):
            GameView(
                setup: setup, seed: seed, mode: .practice,
                onNewMatch: { newSetup in
                    apply(newSetup)
                    phase = .practice(seed: freshSeed())
                },
                onExit: { phase = .menu }
            )
            .id(seed)
        case .arcade:
            ArcadeView(setup: setup, onExit: { phase = .menu })
        }
    }

    /// The stored setup as one value.
    private var setup: Setup {
        Setup(
            pointsToWin: pointsToWin, gamesToWin: gamesToWin, puckShapeKey: puckShapeKey,
            randomPuck: randomPuck, puckCount: puckCount, randomPuckCount: randomPuckCount,
            bottomHands: bottomHands, topHands: topHands,
            wrapWalls: wrapWalls, randomWalls: randomWalls)
    }

    /// A binding the front-door pickers edit directly (there is no game to
    /// disturb, so every change lands straight in storage).
    private var setupBinding: Binding<Setup> {
        Binding(get: { setup }, set: apply)
    }

    /// Write a setup back to the individual stored fields.
    private func apply(_ s: Setup) {
        pointsToWin = s.pointsToWin
        gamesToWin = s.gamesToWin
        puckShapeKey = s.puckShapeKey
        randomPuck = s.randomPuck
        puckCount = s.puckCount
        randomPuckCount = s.randomPuckCount
        bottomHands = s.bottomHands
        topHands = s.topHands
        wrapWalls = s.wrapWalls
        randomWalls = s.randomWalls
    }

    private func freshSeed() -> UInt64 { UInt64.random(in: 0...UInt64.max) }
}
