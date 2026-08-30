import PuckaroundCore
import SwiftUI

/// **The tournament flow.** Pick tonight's players, then alternate the table (a
/// match per pairing, played with the stored setup) with an interstitial naming
/// the pairing, who's up next and the running tally. Winner stays; the loser
/// rejoins the line. The whole evening survives the app quitting: the state
/// mirrors to storage on every change, and reopening resumes it.
struct TournamentView: View {
    /// The evening's match rules — the same stored setup as a plain match; the
    /// roster sheet edits it in place.
    @Binding var setup: Setup
    let onExit: () -> Void

    /// The active tournament, JSON-mirrored to storage on every change.
    @AppStorage("puckaround.tournament") private var saved = Data()
    @State private var tournament: Tournament?
    @State private var stage = Stage.lobby

    private enum Stage: Equatable {
        case lobby
        case interstitial
        case playing(seed: UInt64)
    }

    var body: some View {
        ZStack {
            Neon.ground.ignoresSafeArea()
            switch stage {
            case .lobby:
                RosterSheet(setup: $setup, onStart: begin, onClose: onExit)
            case .interstitial:
                if let tournament {
                    interstitial(tournament)
                }
            case .playing(let seed):
                if let tournament {
                    match(tournament, seed: seed)
                        .id(seed)
                }
            }
        }
        .onAppear(perform: resume)
    }

    /// One pairing on the table. The pause menu's exit leads back to the
    /// interstitial, not the title — the tournament owns the table now.
    private func match(_ t: Tournament, seed: UInt64) -> some View {
        // A pairing is two people: whatever the stored format says, a
        // tournament match fields one mallet per name.
        var single = setup
        single.bottomHands = 1
        single.topHands = 1
        return GameView(
            setup: single, seed: seed,
            tournament: TournamentMatch(
                names: EndNames(bottom: t.bottom, top: t.top), onMatchOver: recordWin),
            onNewMatch: { _ in stage = .playing(seed: freshSeed()) },
            onExit: { stage = .interstitial })
    }

    /// Between matches: the pairing, the line, the tally — and the way on or out.
    private func interstitial(_ t: Tournament) -> some View {
        ZStack {
            VStack(spacing: 24) {
                header
                if let last = t.lastMatch {
                    Text(
                        "\(last.winner) beat \(last.loser) \(last.winnerScore)–\(last.loserScore)",
                        bundle: .module
                    )
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Neon.inkSoft)
                }
                pairing(t)
                if let next = t.upNext {
                    HStack(spacing: 6) {
                        Text("Up next", bundle: .module)
                            .foregroundStyle(Neon.inkSoft)
                        Text(verbatim: next)
                            .foregroundStyle(Neon.ink)
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                // Runs only speak once they're runs — a single win says nothing.
                if let holder = t.streakName, t.streak >= 2 {
                    Text("\(holder) has \(t.streak) in a row", bundle: .module)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Neon.ink)
                }
                standings(t)
                if let best = t.bestStreakName, t.bestStreak >= 2 {
                    Text("Longest run: \(best) · \(t.bestStreak)", bundle: .module)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Neon.inkSoft)
                }
                NeonButton(title: "Start match", tint: Neon.cyan, prominent: true) {
                    stage = .playing(seed: freshSeed())
                }
                NeonButton(title: "End tournament", tint: Neon.magenta, action: end)
            }
            .padding(24)
            .frame(maxWidth: 440)
            .background(NeonCard())
            .padding(16)
        }
    }

    /// The title, with an X that leaves for the title screen — the tournament
    /// stays saved, and coming back resumes it.
    private var header: some View {
        ZStack {
            Text("Tournament", bundle: .module)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Neon.ink)
            HStack {
                Spacer()
                NeonIconButton(systemName: "xmark", label: "Close", action: onExit)
            }
        }
    }

    /// Who takes the table, each name in their end's color.
    private func pairing(_ t: Tournament) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: t.bottom)
                .foregroundStyle(Neon.magenta)
            Text("VS.", bundle: .module)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Neon.inkSoft)
            Text(verbatim: t.top)
                .foregroundStyle(Neon.cyan)
        }
        .font(.system(size: 26, weight: .black, design: .rounded))
    }

    /// Tonight's tally, most wins first.
    private func standings(_ t: Tournament) -> some View {
        VStack(spacing: 6) {
            ForEach(t.standings, id: \.name) { row in
                HStack {
                    Text(verbatim: row.name)
                        .foregroundStyle(Neon.ink)
                    Spacer()
                    Text(verbatim: "\(row.wins)")
                        .foregroundStyle(Neon.inkSoft)
                        .monospacedDigit()
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
        }
        .frame(maxWidth: 260)
    }

    /// Roster picked: seat the first two and take the table.
    private func begin(_ roster: [String]) {
        guard let t = Tournament(roster: roster) else { return }
        tournament = t
        persist()
        stage = .interstitial
    }

    /// The sim decided the match: tally it and cut straight to the interstitial
    /// — the banner carries the result, so the table needs no verdict beat (and
    /// nobody can sneak a rematch in behind one).
    private func recordWin(_ side: Side, won: Int, lost: Int) {
        tournament?.recordWin(by: side, winnerScore: won, loserScore: lost)
        persist()
        stage = .interstitial
    }

    /// A saved evening resumes right at the interstitial.
    private func resume() {
        guard tournament == nil,
            let t = try? JSONDecoder().decode(Tournament.self, from: saved)
        else { return }
        tournament = t
        stage = .interstitial
    }

    private func end() {
        tournament = nil
        saved = Data()
        onExit()
    }

    private func persist() {
        saved = (try? JSONEncoder().encode(tournament)) ?? Data()
    }

    private func freshSeed() -> UInt64 { UInt64.random(in: 0...UInt64.max) }
}
