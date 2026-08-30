import PuckaroundCore
import SwiftUI

/// **The tournament flow.** Pick tonight's players and a shape, then alternate
/// the table (a match per pairing, played with the stored setup) with an
/// interstitial carrying the last result and what the shape has to say — the
/// line and tally for winner-stays, the drawn sheet for a bracket, the champion
/// when one stands. The whole evening survives the app quitting: the state
/// mirrors to storage on every change, and reopening resumes it.
struct TournamentView: View {
    /// The evening's match rules — the same stored setup as a plain match; the
    /// roster sheet edits it in place.
    @Binding var setup: Setup
    let onExit: () -> Void

    /// The active evening, JSON-mirrored to storage on every change.
    @AppStorage("puckaround.tournament") private var saved = Data()
    @State private var evening: Evening?
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
                if let evening {
                    interstitial(evening)
                }
            case .playing(let seed):
                if let pairing = evening?.pairing {
                    match(pairing, seed: seed)
                        .id(seed)
                }
            }
        }
        .onAppear(perform: resume)
    }

    /// One pairing on the table. The pause menu's exit leads back to the
    /// interstitial, not the title — the tournament owns the table now.
    private func match(_ pairing: Pairing, seed: UInt64) -> some View {
        // A pairing is two people: whatever the stored format says, a
        // tournament match fields one mallet per name.
        var single = setup
        single.bottomHands = 1
        single.topHands = 1
        return GameView(
            setup: single, seed: seed,
            tournament: TournamentMatch(
                names: EndNames(bottom: pairing.bottom, top: pairing.top),
                onMatchOver: recordWin),
            onNewMatch: { _ in stage = .playing(seed: freshSeed()) },
            onExit: { stage = .interstitial })
    }

    /// Between matches: the last result, then the pairing (or the champion),
    /// then whatever the shape has to show — and the way on or out.
    private func interstitial(_ e: Evening) -> some View {
        VStack(spacing: 24) {
            header
            if let last = e.lastMatch {
                lastResult(last)
            }
            if let champion = e.champion {
                championBanner(champion)
            } else if let pairing = e.pairing {
                pairingView(pairing)
            }
            details(e)
            if e.champion == nil {
                NeonButton(title: "Start match", tint: Neon.cyan, prominent: true) {
                    stage = .playing(seed: freshSeed())
                }
            }
            NeonButton(title: "End tournament", tint: Neon.magenta, action: end)
        }
        .padding(24)
        .frame(maxWidth: 440)
        .background(NeonCard())
        .padding(16)
    }

    /// What the shape shows between matches.
    @ViewBuilder
    private func details(_ e: Evening) -> some View {
        switch e {
        case .winnerStays(let t):
            lineDetails(t)
        case .bracket(let b):
            BracketSheet(rounds: b.rounds, current: b.current)
        }
    }

    /// Roster picked: draw the shape and take the table.
    private func begin(_ roster: [String], _ shape: Evening.Shape) {
        switch shape {
        case .winnerStays:
            guard let t = Tournament(roster: roster) else { return }
            evening = .winnerStays(t)
        case .bracket:
            guard let b = Bracket(roster: roster, seed: freshSeed()) else { return }
            evening = .bracket(b)
        }
        persist()
        stage = .interstitial
    }

    /// The sim decided the match: record it and cut straight to the interstitial
    /// — the banner carries the result, so the table needs no verdict beat.
    private func recordWin(_ side: Side, won: Int, lost: Int) {
        evening?.recordWin(by: side, winnerScore: won, loserScore: lost)
        persist()
        stage = .interstitial
    }

    /// A saved evening resumes right at the interstitial.
    private func resume() {
        guard evening == nil,
            let e = try? JSONDecoder().decode(Evening.self, from: saved)
        else { return }
        evening = e
        stage = .interstitial
    }

    private func end() {
        evening = nil
        saved = Data()
        onExit()
    }

    private func persist() {
        saved = (try? JSONEncoder().encode(evening)) ?? Data()
    }

    private func freshSeed() -> UInt64 { UInt64.random(in: 0...UInt64.max) }
}

// MARK: - Interstitial pieces

extension TournamentView {
    /// The title, with an X that leaves for the title screen — the evening
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

    /// The scoreline of the match just played: winner bright, loser dim, and
    /// deliberately monochrome — the side colors belong to the live pairing
    /// below, so what just happened can't be mistaken for what's next.
    private func lastResult(_ last: MatchResult) -> some View {
        VStack(spacing: 4) {
            caption("Last match")
            HStack(spacing: 8) {
                Text(verbatim: last.winner)
                    .foregroundStyle(Neon.ink)
                Text(verbatim: "\(last.winnerScore)–\(last.loserScore)")
                    .foregroundStyle(Neon.inkSoft)
                    .monospacedDigit()
                Text(verbatim: last.loser)
                    .foregroundStyle(Neon.inkSoft)
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
        }
    }

    /// Who takes the table, each name in their end's color.
    private func pairingView(_ pairing: Pairing) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: pairing.bottom)
                .foregroundStyle(Neon.magenta)
            Text("VS.", bundle: .module)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Neon.inkSoft)
            Text(verbatim: pairing.top)
                .foregroundStyle(Neon.cyan)
        }
        .font(.system(size: 26, weight: .black, design: .rounded))
    }

    /// The last name standing, once the knockout is decided.
    private func championBanner(_ name: String) -> some View {
        VStack(spacing: 4) {
            caption("Champion")
            Text(verbatim: name)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(Neon.cyan)
                .shadow(color: Neon.cyan.opacity(0.7), radius: 10)
        }
    }

    /// The winner-stays middle: the line, the streaks, the tally.
    private func lineDetails(_ t: Tournament) -> some View {
        VStack(spacing: 24) {
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
        }
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

    /// The small uppercase label above a banner block.
    private func caption(_ key: LocalizedStringKey) -> some View {
        Text(key, bundle: .module)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Neon.inkSoft)
            .textCase(.uppercase)
            .kerning(2)
    }
}
