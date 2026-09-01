import PuckaroundCore
import SwiftUI

/// A cabinet's attract screen: the table itself as the marquee — drawn by the
/// real renderer at tick zero — with the ten-line board floating over the
/// playfield, the way cabinets always had it. Play drops the board and takes
/// the table; a finished run lands back here, pen out if it boarded.
struct ArcadeCabinet: View {
    let machine: ArcadeMachine
    let board: Hiscores
    let pool: [NamedPlayer]
    let lastScore: Int?
    let pendingScore: Int?
    let onPlay: () -> Void
    let onBack: () -> Void
    let onSign: (String) -> Void
    let onSkip: () -> Void

    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 18) {
                    attract
                    if let pendingScore {
                        signSection(pendingScore)
                    } else if let lastScore {
                        lastRun(lastScore)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            NeonButton(title: "Play", tint: Neon.cyan, prominent: true, action: onPlay)
                .padding(24)
        }
        .frame(maxWidth: 440)
        .background(NeonCard())
        .padding(16)
    }

    private var header: some View {
        ZStack {
            Text(machine.title, bundle: .module)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Neon.ink)
            HStack {
                NeonIconButton(systemName: "chevron.left", label: "Back", action: onBack)
                Spacer()
            }
        }
    }

    /// The playfield with the board on top — a game not ongoing wears its
    /// scores right on the table.
    private var attract: some View {
        ZStack {
            TablePreview(table: machine.table)
            boardOverlay
        }
        .frame(maxHeight: 400)
    }

    private var boardOverlay: some View {
        VStack(spacing: 6) {
            caption("Best runs")
            if board.entries.isEmpty {
                Text("No runs yet", bundle: .module)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Neon.inkSoft)
            } else {
                ForEach(Array(board.entries.enumerated()), id: \.offset) { rank, entry in
                    HStack(spacing: 10) {
                        Text(verbatim: "\(rank + 1).")
                            .foregroundStyle(Neon.inkSoft)
                            .monospacedDigit()
                            .frame(width: 24, alignment: .trailing)
                        Text(verbatim: entry.name)
                            .foregroundStyle(kitColor(entry.name))
                            .lineLimit(1)
                        Spacer()
                        Text(verbatim: "\(entry.score)")
                            .foregroundStyle(Neon.ink)
                            .monospacedDigit()
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: 250)
        .background(RoundedRectangle(cornerRadius: 12).fill(Neon.ground.opacity(0.72)))
    }

    private func kitColor(_ name: String) -> Color {
        SeatPalette.neon(PlayerPool.kit(for: name, in: pool).home)
    }

    /// The last run's score when it didn't board — still worth showing.
    private func lastRun(_ score: Int) -> some View {
        VStack(spacing: 4) {
            caption("Last run")
            scoreText(score)
        }
    }

    /// A boarded run waits for its name: one tap on a pool chip signs it, or
    /// a new name types in — joining the pool like anywhere else.
    private func signSection(_ score: Int) -> some View {
        VStack(spacing: 12) {
            caption("Sign the board")
            scoreText(score)
            poolChips
            signField
            Button(action: onSkip) {
                Text("Skip", bundle: .module)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Neon.inkSoft)
                    .frame(height: 30)
            }
            .buttonStyle(.plain)
        }
    }

    private func scoreText(_ score: Int) -> some View {
        Text(verbatim: "\(score)")
            .font(.system(size: 34, weight: .black, design: .rounded))
            .foregroundStyle(Neon.cyan)
            .monospacedDigit()
            .shadow(color: Neon.cyan.opacity(0.7), radius: 10)
    }

    private var poolChips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            ForEach(pool, id: \.name) { player in
                Button {
                    onSign(player.name)
                } label: {
                    Text(verbatim: player.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(SeatPalette.neon(player.kit.home))
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    SeatPalette.neon(player.kit.home).opacity(0.5),
                                    lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var signField: some View {
        TextField(text: $newName, prompt: Text("Add name", bundle: .module)) {
            Text("Add name", bundle: .module)
        }
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .foregroundStyle(Neon.ink)
        .textFieldStyle(.plain)
        .submitLabel(.done)
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Neon.inkSoft.opacity(0.6), lineWidth: 1.5)
        )
        .onSubmit {
            let name = newName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, name.count <= RosterSheet.maxNameLength else { return }
            newName = ""
            onSign(name)
        }
    }

    private func caption(_ key: LocalizedStringKey) -> some View {
        Text(key, bundle: .module)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Neon.inkSoft)
            .textCase(.uppercase)
            .kerning(2)
    }
}

/// A table drawn as it will play — through the real renderer, at tick zero:
/// the furniture, a fresh run's HUD. The game is its own marquee art, and a
/// spec change redraws itself for free. `crop` shows only that fraction of
/// the table from the top — an index icon crops to the signature furniture
/// (the far goal, the bumpers, the wall) instead of the whole field.
struct TablePreview: View {
    let table: Playfield
    var crop: Double = 1

    var body: some View {
        Canvas { context, size in
            // Lay the FULL board out at the view's width; the view's aspect
            // only admits the top `crop` of it, and the rest clips away.
            let full = CGSize(
                width: size.width, height: size.width * table.size.y / table.size.x)
            let rink = Rink(table: table, seed: 0)
            let scene = RinkScene(
                rink: rink,
                placement: BoardPlacement(board: table.size, screen: full),
                reducedMotion: true, arcade: ScoreAttack())
            RinkRenderer.draw(scene, in: &context, size: full)
        }
        .aspectRatio(table.size.x / (table.size.y * crop), contentMode: .fit)
        .clipped()
    }
}
