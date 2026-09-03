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
    /// The remembered pool — read here for the players' kits. Decoded once
    /// into state (and on external writes), never per row: the interstitial
    /// lists color every name, and a JSON decode per name was real work.
    @AppStorage("puckaround.playerNames") private var savedPool = Data()
    @State private var pool: [NamedPlayer] = []
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
        .onChangeCompat(of: savedPool) { pool = PlayerPool.decode($0) }
    }

    /// One pairing on the table. The pause menu's exit leads back to the
    /// interstitial, not the title — the tournament owns the table now.
    private func match(_ pairing: Pairing, seed: UInt64) -> some View {
        let colors =
            evening.map { resolvedColors($0, pairing) }
            ?? EndColors(bottom: Neon.magenta, top: Neon.cyan)
        return GameView(
            setup: setup, seed: seed,
            mode: .tournament(
                TournamentMatch(
                    names: EndNames(bottom: pairing.bottom, top: pairing.top),
                    colors: colors, onMatchOver: recordWin)),
            onNewMatch: { _ in stage = .playing(seed: freshSeed()) },
            onExit: { stage = .interstitial })
    }

    /// The pairing's clash-resolved kit colors, from the remembered pool.
    private func resolvedColors(_ e: Evening, _ pairing: Pairing) -> EndColors {
        let resolved = PlayerKit.resolve(
            bottom: PlayerPool.kit(for: pairing.bottom, in: pool),
            top: PlayerPool.kit(for: pairing.top, in: pool),
            homeSide: homeSide(e, pairing))
        return EndColors(
            bottom: SeatPalette.neon(resolved.bottom), top: SeatPalette.neon(resolved.top))
    }

    /// Who's home in a kit clash: the winner-stays incumbent defends their
    /// turf; in the other shapes the bottom end is home.
    private func homeSide(_ e: Evening, _ pairing: Pairing) -> Side {
        if case .winnerStays = e, e.lastMatch?.winner == pairing.top { return .top }
        return .bottom
    }

    /// A name's home color, for the neutral lists between matches.
    private func kitColor(_ name: String) -> Color {
        SeatPalette.neon(PlayerPool.kit(for: name, in: pool).home)
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
                pairingView(pairing, colors: resolvedColors(e, pairing))
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
        .frame(maxWidth: Neon.sheetWidth)
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
        case .league(let l):
            leagueDetails(l)
        }
    }

    /// Roster picked: draw the shape and take the table.
    private func begin(_ roster: [String], _ plan: EveningPlan) {
        switch plan {
        case .winnerStays:
            guard let t = Tournament(roster: roster) else { return }
            evening = .winnerStays(t)
        case .bracket:
            guard let b = Bracket(roster: roster, seed: freshSeed()) else { return }
            evening = .bracket(b)
        case .league(let doubleRound):
            guard let l = League(roster: roster, doubleRound: doubleRound, seed: freshSeed())
            else { return }
            evening = .league(l)
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
        pool = PlayerPool.decode(savedPool)
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
        NeonSheetHeader(title: "Tournament", onClose: onExit)
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
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
    }

    /// Who takes the table, each name in the kit their end will wear.
    private func pairingView(_ pairing: Pairing, colors: EndColors) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: pairing.bottom)
                .foregroundStyle(colors.bottom)
            Text("VS.", bundle: .module)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Neon.inkSoft)
            Text(verbatim: pairing.top)
                .foregroundStyle(colors.top)
        }
        .font(.system(size: 26, weight: .black, design: .rounded))
        // Entry caps names, but a long one from an older save shrinks to fit
        // rather than pushing past the card.
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    /// The last name standing, once the knockout is decided — in their own kit.
    private func championBanner(_ name: String) -> some View {
        let color = kitColor(name)
        return VStack(spacing: 4) {
            caption("Champion")
            Text(verbatim: name)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.7), radius: 10)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
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

    /// Tonight's tally, most wins first, each name in its home kit.
    private func standings(_ t: Tournament) -> some View {
        VStack(spacing: 6) {
            ForEach(t.standings, id: \.name) { row in
                HStack {
                    Text(verbatim: row.name)
                        .foregroundStyle(kitColor(row.name))
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

    /// The league middle: where the season stands, then the table so far.
    private func leagueDetails(_ l: League) -> some View {
        VStack(spacing: 12) {
            if l.contenders != nil {
                // The season ended tied — sudden death until one name stands.
                caption("Deciders")
            } else if l.champion == nil {
                Text("Match \(l.played.count + 1) of \(l.fixtures.count)", bundle: .module)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Neon.inkSoft)
            }
            leagueStandings(l)
        }
    }

    /// The league table, best first: wins–losses per name, in home kits.
    private func leagueStandings(_ l: League) -> some View {
        VStack(spacing: 6) {
            ForEach(l.standings, id: \.name) { row in
                HStack {
                    Text(verbatim: row.name)
                        .foregroundStyle(kitColor(row.name))
                        .lineLimit(1)
                    Spacer()
                    Text(verbatim: "\(row.wins)–\(row.losses)")
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
        NeonCaption(title: key)
    }
}
