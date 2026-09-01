import PuckaroundCore
import SwiftUI

/// What floats over the LIVE table while the rink waits at faceoff — the
/// cabinet's attract screen: the ten-line board on the machine's empty half,
/// and after a run its score with the pen out if it boarded. There is no
/// start button; grabbing the mallet is the start button, like every table.
struct ArcadeAttract: View {
    let board: Hiscores
    let pool: [NamedPlayer]
    let lastScore: Int?
    let pendingScore: Int?
    let onSign: (String) -> Void
    let onSkip: () -> Void

    @State private var newName = ""

    var body: some View {
        ZStack {
            // The board keeps to the machine's empty half, up top.
            VStack {
                VStack(spacing: 12) {
                    if pendingScore == nil, let lastScore {
                        card { lastRun(lastScore) }
                    }
                    card { boardRows }
                }
                .frame(maxWidth: 290)
                Spacer()
            }
            .padding(.top, 24)
            // The pen demands the middle of the screen, fully solid — and it
            // leaves the moment a name lands, handing back to the board.
            if let pendingScore {
                card(opacity: 1) { signSection(pendingScore) }
                    .frame(maxWidth: 300)
            }
        }
        .padding(.horizontal, 24)
    }

    /// A near-opaque pane with a defined edge: the table's glow, rings and
    /// furniture must not bleed through the text.
    private func card(
        opacity: Double = 0.94, @ViewBuilder body: () -> some View
    ) -> some View {
        VStack(spacing: 8, content: body)
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Neon.ground.opacity(opacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Neon.inkSoft.opacity(0.35), lineWidth: 1)))
    }

    @ViewBuilder
    private var boardRows: some View {
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

    private func kitColor(_ name: String) -> Color {
        SeatPalette.neon(PlayerPool.kit(for: name, in: pool).home)
    }

    /// The last run's score when it didn't board — still worth showing.
    @ViewBuilder
    private func lastRun(_ score: Int) -> some View {
        caption("Last run")
        scoreText(score)
    }

    /// A boarded run waits for its name: one tap on a pool chip signs it, or
    /// a new name types in — joining the pool like anywhere else.
    @ViewBuilder
    private func signSection(_ score: Int) -> some View {
        caption("Sign the board")
        scoreText(score)
        poolChips
        signField
        Button(action: onSkip) {
            Text("Skip", bundle: .module)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Neon.inkSoft)
                .frame(height: 28)
        }
        .buttonStyle(.plain)
    }

    private func scoreText(_ score: Int) -> some View {
        Text(verbatim: "\(score)")
            .font(.system(size: 30, weight: .black, design: .rounded))
            .foregroundStyle(Neon.cyan)
            .monospacedDigit()
            .shadow(color: Neon.cyan.opacity(0.7), radius: 10)
    }

    private var poolChips: some View {
        // Only the freshest chips: the pool is most-recent-first, so whoever
        // is holding the phone is almost always here — a huge pool must not
        // shove the pane off screen. Anyone rarer types below; the field
        // knows every name.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
            ForEach(pool.prefix(8), id: \.name) { player in
                Button {
                    onSign(player.name)
                } label: {
                    Text(verbatim: player.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(SeatPalette.neon(player.kit.home))
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
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
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(Neon.ink)
        .textFieldStyle(.plain)
        .submitLabel(.done)
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 10)
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
