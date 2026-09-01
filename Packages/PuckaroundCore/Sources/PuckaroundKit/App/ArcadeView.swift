import PuckaroundCore
import SwiftUI

/// The arcade's canonical configs — one per minigame, never from the setup: a
/// board means nothing if its runs played different tables.
enum ArcadeSpec {
    /// The sim must never end an arcade game itself; the score-attack loop
    /// does. Every serve comes to the player, like practice.
    static let rules = Rules(pointsToWin: 1_000_000, gamesToWin: 1, serveTo: .bottom)

    /// Bumper field: your mallet is the flipper. One disc, solid walls, nobody
    /// home up top — three bumpers guard the target goal and pay per clang.
    static var bumperField: Playfield {
        var table = Playfield.duel.with(format: .solo)
        table.bumpers = [
            Bumper(position: Vec2(30, 46), radius: 6, kick: 60),
            Bumper(position: Vec2(70, 46), radius: 6, kick: 60),
            Bumper(position: Vec2(50, 32), radius: 6, kick: 60),
        ]
        return table
    }
}

/// **The arcade.** Solo minigames on the game's own physics, behind one shelf
/// so the front door stays "people around one screen". Each minigame keeps a
/// ten-line board, signed from the same remembered pool as tournaments.
struct ArcadeView: View {
    /// The stored setup — the arcade never reads it, but the table view needs
    /// one for its plumbing.
    let setup: Setup
    let onExit: () -> Void

    /// The bumper-field board, JSON in storage.
    @AppStorage("puckaround.hiscores.bumperField") private var savedBoard = Data()
    @AppStorage("puckaround.playerNames") private var savedPool = Data()
    @State private var stage = Stage.shelf
    /// A finished run that made the board, waiting for its signature.
    @State private var pendingScore: Int?
    /// The last run's score, shown on the shelf between games.
    @State private var lastScore: Int?
    @State private var newName = ""

    private enum Stage: Equatable {
        case shelf
        case playing(seed: UInt64)
    }

    var body: some View {
        ZStack {
            Neon.ground.ignoresSafeArea()
            switch stage {
            case .shelf:
                shelf
            case .playing(let seed):
                game(seed: seed).id(seed)
            }
        }
    }

    private var board: Hiscores {
        (try? JSONDecoder().decode(Hiscores.self, from: savedBoard)) ?? Hiscores()
    }

    private func game(seed: UInt64) -> some View {
        GameView(
            setup: setup, seed: seed,
            mode: .arcade(
                ArcadeTable(
                    table: ArcadeSpec.bumperField, rules: ArcadeSpec.rules,
                    onGameOver: gameOver)),
            onNewMatch: { _ in stage = .playing(seed: freshSeed()) },
            onExit: { stage = .shelf })
    }

    /// The run ended: back to the shelf, with the pen out if it boarded.
    private func gameOver(_ score: Int) {
        lastScore = score
        pendingScore = board.qualifies(score) ? score : nil
        stage = .shelf
    }

    private var shelf: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 24) {
                    if let pendingScore {
                        signSection(pendingScore)
                    } else if let lastScore {
                        lastRun(lastScore)
                    }
                    bumperCard
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: 440)
        .background(NeonCard())
        .padding(16)
    }

    private var header: some View {
        ZStack {
            Text("Arcade", bundle: .module)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Neon.ink)
            HStack {
                Spacer()
                NeonIconButton(systemName: "xmark", label: "Close", action: onExit)
            }
        }
    }

    private var bumperCard: some View {
        VStack(spacing: 14) {
            Text("Bumper Field", bundle: .module)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Neon.cyan)
            boardRows
            NeonButton(title: "Play", tint: Neon.cyan, prominent: true) {
                lastScore = nil
                pendingScore = nil
                stage = .playing(seed: freshSeed())
            }
        }
    }

    /// The board: rank, name (in its home kit), score — a cabinet's lines.
    @ViewBuilder
    private var boardRows: some View {
        let entries = board.entries
        if entries.isEmpty {
            Text("No runs yet", bundle: .module)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Neon.inkSoft)
        } else {
            let pool = PlayerPool.decode(savedPool)
            VStack(spacing: 5) {
                ForEach(Array(entries.enumerated()), id: \.offset) { rank, entry in
                    HStack(spacing: 10) {
                        Text(verbatim: "\(rank + 1).")
                            .foregroundStyle(Neon.inkSoft)
                            .monospacedDigit()
                            .frame(width: 26, alignment: .trailing)
                        Text(verbatim: entry.name)
                            .foregroundStyle(
                                SeatPalette.neon(PlayerPool.kit(for: entry.name, in: pool).home)
                            )
                            .lineLimit(1)
                        Spacer()
                        Text(verbatim: "\(entry.score)")
                            .foregroundStyle(Neon.ink)
                            .monospacedDigit()
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
            }
            .frame(maxWidth: 300)
        }
    }

    private func freshSeed() -> UInt64 { UInt64.random(in: 0...UInt64.max) }
}

// MARK: - Signing a run

extension ArcadeView {
    /// The last run's score when it didn't board — still worth showing.
    fileprivate func lastRun(_ score: Int) -> some View {
        VStack(spacing: 4) {
            caption("Last run")
            scoreText(score)
        }
    }

    /// A boarded run waits for its name: one tap on a pool chip signs it, or a
    /// new name types in — joining the pool like anywhere else.
    fileprivate func signSection(_ score: Int) -> some View {
        VStack(spacing: 12) {
            caption("Sign the board")
            scoreText(score)
            poolChips
            signField
            Button {
                pendingScore = nil
            } label: {
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
        let pool = PlayerPool.decode(savedPool)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            ForEach(pool, id: \.name) { player in
                Button {
                    sign(player.name)
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
            var pool = PlayerPool.decode(savedPool)
            if !pool.contains(where: { $0.name == name }) {
                pool.insert(NamedPlayer(name: name, kit: .assigned(to: name)), at: 0)
                savedPool = PlayerPool.encode(pool)
            }
            newName = ""
            sign(name)
        }
    }

    private func sign(_ name: String) {
        guard let score = pendingScore else { return }
        var signed = board
        _ = signed.submit(name: name, score: score)
        savedBoard = (try? JSONEncoder().encode(signed)) ?? Data()
        pendingScore = nil
    }

    private func caption(_ key: LocalizedStringKey) -> some View {
        Text(key, bundle: .module)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Neon.inkSoft)
            .textCase(.uppercase)
            .kerning(2)
    }
}
