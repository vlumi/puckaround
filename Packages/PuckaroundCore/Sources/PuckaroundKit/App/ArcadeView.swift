import PuckaroundCore
import SwiftUI

/// One cabinet in the arcade: its identity (also the board's storage key),
/// its marquee title, and the canonical table it always plays — never from
/// the setup, or the board's scores wouldn't compare.
struct ArcadeMachine: Identifiable, Equatable {
    let id: String
    let title: LocalizedStringKey
    let table: Playfield
}

/// The arcade's cabinets, in shelf order. The shared rules: the sim must
/// never end an arcade game itself (the score-attack loop does), and every
/// serve comes to the player.
enum ArcadeSpec {
    static let rules = Rules(pointsToWin: 1_000_000, gamesToWin: 1, serveTo: .bottom)

    static let machines: [ArcadeMachine] = [bumperField, brickWall]

    /// Bumper field: your mallet is the flipper. Nobody home up top — each
    /// stage seats a different bumper pattern guarding the target goal
    /// (triangle, diamond, a bumper wall, twin heavies, the X), some flying
    /// shaped or doubled pucks. Clearing the last loops faster.
    static let bumperField = ArcadeMachine(
        id: "bumperField", title: "Bumper Field",
        table: {
            var table = Playfield.duel.with(format: .solo)
            table.stages = [
                TableStage(bumpers: triangle),
                TableStage(bumpers: diamond),
                TableStage(bumpers: bumperWall, pucks: [.square]),
                TableStage(bumpers: twins, pucks: [.circle, .circle]),
                TableStage(bumpers: cross, pucks: [.circle, .square]),
            ]
            return table
        }())

    private static let triangle = [
        Bumper(position: Vec2(30, 46), radius: 6, kick: 60),
        Bumper(position: Vec2(70, 46), radius: 6, kick: 60),
        Bumper(position: Vec2(50, 32), radius: 6, kick: 60),
    ]
    private static let diamond = [
        Bumper(position: Vec2(50, 24), radius: 6, kick: 60),
        Bumper(position: Vec2(28, 40), radius: 6, kick: 60),
        Bumper(position: Vec2(72, 40), radius: 6, kick: 60),
        Bumper(position: Vec2(50, 56), radius: 6, kick: 60),
    ]
    /// A wall of small bumpers straight across the approach.
    private static let bumperWall = [18.0, 34, 50, 66, 82].map {
        Bumper(position: Vec2($0, 36), radius: 3.5, kick: 50)
    }
    private static let twins = [
        Bumper(position: Vec2(38, 38), radius: 8, kick: 70),
        Bumper(position: Vec2(62, 38), radius: 8, kick: 70),
    ]
    private static let cross = [
        Bumper(position: Vec2(26, 28), radius: 5, kick: 60),
        Bumper(position: Vec2(74, 28), radius: 5, kick: 60),
        Bumper(position: Vec2(50, 40), radius: 6, kick: 70),
        Bumper(position: Vec2(26, 52), radius: 5, kick: 60),
        Bumper(position: Vec2(74, 52), radius: 5, kick: 60),
    ]

    /// Brick Wall's deliberate stages: walls grow and turn sturdy, tumbling
    /// shapes replace the calm disc, later stages fly two and three pucks at
    /// once — each new idea debuting somewhere it's legible. Clearing the
    /// last loops back to the first with the pace turned up, lap after lap,
    /// until the run finally ends.
    static let brickWall = ArcadeMachine(
        id: "brickWall", title: "Brick Wall",
        table: {
            var table = Playfield.duel.with(format: .solo)
            table.stages = [
                TableStage(bricks: wall(rows: 1, hits: 1)),
                TableStage(bricks: wall(rows: 3, hits: 1)),
                TableStage(bricks: wall(rows: 2, hits: 2), pucks: [.square]),
                TableStage(bricks: wall(rows: 4, hits: 1), pucks: [.circle, .circle]),
                TableStage(bricks: wall(rows: 3, hits: 2), pucks: [.triangle]),
                TableStage(bricks: wall(rows: 5, hits: 1), pucks: [.circle, .square]),
                TableStage(bricks: wall(rows: 4, hits: 2), pucks: [.circle, .circle, .circle]),
                TableStage(bricks: wall(rows: 3, hits: 3), pucks: [.square, .triangle]),
                TableStage(bricks: wall(rows: 5, hits: 3), pucks: [.circle, .square, .triangle]),
            ]
            return table
        }())

    /// One Brick Wall rack: full-width rows down from the goal, every brick
    /// `hits` strong.
    private static func wall(rows: Int, hits: Int) -> [Brick] {
        (0..<(rows * 7)).map { index in
            let column = Double(index % 7)
            let row = Double(index / 7)
            return Brick(
                rect: Rect(x: 8 + column * 12, y: 12 + row * 6, width: 12, height: 6),
                hits: hits)
        }
    }
}

/// **The arcade.** Solo minigames on the game's own physics, behind one shelf
/// so the front door stays "people around one screen". The index shows each
/// cabinet as its own table — the game is the marquee — and each cabinet's
/// attract screen floats its ten-line board over the playfield until Play.
struct ArcadeView: View {
    /// The stored setup — the arcade never reads it, but the table view needs
    /// one for its plumbing.
    let setup: Setup
    let onExit: () -> Void

    @AppStorage("puckaround.hiscores.bumperField") private var bumperBoard = Data()
    @AppStorage("puckaround.hiscores.brickWall") private var brickBoard = Data()
    @AppStorage("puckaround.playerNames") private var savedPool = Data()
    @State private var stage = Stage.index
    /// A finished run that made the board, waiting for its signature.
    @State private var pendingScore: Int?
    /// The last run's score, shown on the cabinet between games.
    @State private var lastScore: Int?

    private enum Stage: Equatable {
        case index
        case cabinet(ArcadeMachine)
        case playing(ArcadeMachine, seed: UInt64)
    }

    var body: some View {
        ZStack {
            Neon.ground.ignoresSafeArea()
            switch stage {
            case .index:
                index
            case .cabinet(let machine):
                ArcadeCabinet(
                    machine: machine, board: board(for: machine),
                    pool: PlayerPool.decode(savedPool),
                    lastScore: lastScore, pendingScore: pendingScore,
                    onPlay: {
                        lastScore = nil
                        pendingScore = nil
                        stage = .playing(machine, seed: freshSeed())
                    },
                    onBack: { stage = .index },
                    onSign: { name in sign(name, on: machine) },
                    onSkip: { pendingScore = nil })
            case .playing(let machine, let seed):
                game(machine, seed: seed).id(seed)
            }
        }
    }

    private func game(_ machine: ArcadeMachine, seed: UInt64) -> some View {
        GameView(
            setup: setup, seed: seed,
            mode: .arcade(
                ArcadeTable(
                    table: machine.table, rules: ArcadeSpec.rules,
                    onGameOver: { score in gameOver(score, on: machine) })),
            onNewMatch: { _ in stage = .playing(machine, seed: freshSeed()) },
            onExit: { stage = .cabinet(machine) })
    }

    /// The run ended: back to the attract screen, pen out if it boarded.
    private func gameOver(_ score: Int, on machine: ArcadeMachine) {
        lastScore = score
        pendingScore = board(for: machine).qualifies(score) ? score : nil
        stage = .cabinet(machine)
    }

    /// Sign the waiting run — a brand-new name joins the pool like anywhere.
    private func sign(_ name: String, on machine: ArcadeMachine) {
        guard let score = pendingScore else { return }
        var pool = PlayerPool.decode(savedPool)
        if !pool.contains(where: { $0.name == name }) {
            pool.insert(NamedPlayer(name: name, kit: .assigned(to: name)), at: 0)
            savedPool = PlayerPool.encode(pool)
        }
        var signed = board(for: machine)
        _ = signed.submit(name: name, score: score)
        setBoard(signed, for: machine)
        pendingScore = nil
    }

    private func board(for machine: ArcadeMachine) -> Hiscores {
        let data = machine.id == ArcadeSpec.brickWall.id ? brickBoard : bumperBoard
        return (try? JSONDecoder().decode(Hiscores.self, from: data)) ?? Hiscores()
    }

    private func setBoard(_ board: Hiscores, for machine: ArcadeMachine) {
        let data = (try? JSONEncoder().encode(board)) ?? Data()
        if machine.id == ArcadeSpec.brickWall.id {
            brickBoard = data
        } else {
            bumperBoard = data
        }
    }

    /// The shelf: every cabinet as a card — its table drawn small, its title,
    /// and the line to beat.
    private var index: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                    ForEach(ArcadeSpec.machines) { machine in
                        machineCard(machine)
                    }
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

    private func machineCard(_ machine: ArcadeMachine) -> some View {
        Button {
            lastScore = nil
            pendingScore = nil
            stage = .cabinet(machine)
        } label: {
            VStack(spacing: 8) {
                // Just the top of the table — the far goal and its guardian
                // furniture are the game's signature, not the empty ice.
                TablePreview(table: machine.table, crop: 0.42)
                Text(machine.title, bundle: .module)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Neon.cyan)
                    .lineLimit(1)
                if let top = board(for: machine).entries.first {
                    Text(verbatim: "\(top.score) · \(top.name)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Neon.inkSoft)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Neon.inkSoft.opacity(0.4), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func freshSeed() -> UInt64 { UInt64.random(in: 0...UInt64.max) }
}
