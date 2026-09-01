import PuckaroundCore
import SwiftUI

/// One cabinet in the arcade: its identity (also the board's storage key),
/// its marquee title, and the canonical table it always plays — never from
/// the setup, or the board's scores wouldn't compare.
struct ArcadeMachine: Identifiable, Equatable {
    let id: String
    let title: LocalizedStringKey
    let table: Playfield
    /// The index card's square close-up — the game's signature furniture.
    let icon: ArcadeIcon.Kind
}

/// The arcade's cabinets, in shelf order. The shared rules: the sim must
/// never end an arcade game itself (the score-attack loop does), and every
/// serve comes to the player.
enum ArcadeSpec {
    static let rules = Rules(pointsToWin: 1_000_000, gamesToWin: 1, serveTo: .bottom)

    static let machines: [ArcadeMachine] = [bumperField, brickWall, survival]

    /// Survival: the machine sweeps its goal while the feeder beams in one
    /// more puck every few seconds — shapes cycling, the whole table
    /// relentlessly accelerating. Living pays; every drain costs a life. How
    /// long can you keep your goal clean?
    static let survival = ArcadeMachine(
        id: "survival", title: "Survival",
        table: {
            var table = Playfield.duel
            table.feed = PuckFeed(
                every: 7, cap: 3, shapes: [.circle, .square, .triangle], ramp: 0.015)
            return table
        }(), icon: .pucks)

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
        }(), icon: .bumper)

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
        }(), icon: .bricks)

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
    @AppStorage("puckaround.hiscores.survival") private var survivalBoard = Data()
    @AppStorage("puckaround.playerNames") private var savedPool = Data()
    @State private var stage = Stage.index
    /// A finished run that made the board, waiting for its signature.
    @State private var pendingScore: Int?
    /// The last run's score, shown on the next attract screen.
    @State private var lastScore: Int?
    /// The stage the last run died on (staged cabinets), signed with it.
    @State private var lastStage: Int?

    private enum Stage: Equatable {
        case index
        case playing(ArcadeMachine, seed: UInt64)
    }

    var body: some View {
        ZStack {
            Neon.ground.ignoresSafeArea()
            switch stage {
            case .index:
                index
            case .playing(let machine, let seed):
                game(machine, seed: seed).id(seed)
            }
        }
    }

    /// The live table. Its attract screen is the faceoff itself: the board
    /// (and the pen, after a boarding run) floats on the machine's empty half
    /// until the player grabs their mallet — that grab is the start button.
    private func game(_ machine: ArcadeMachine, seed: UInt64) -> some View {
        GameView(
            setup: setup, seed: seed,
            mode: .arcade(
                ArcadeTable(
                    table: machine.table, rules: ArcadeSpec.rules,
                    attract: AnyView(
                        ArcadeAttract(
                            board: board(for: machine), pool: PlayerPool.decode(savedPool),
                            lastScore: lastScore, pendingScore: pendingScore,
                            pendingStage: lastStage,
                            onSign: { name in sign(name, on: machine) },
                            onSkip: { pendingScore = nil })),
                    onGameOver: { score, stage in gameOver(score, stage: stage, on: machine) })),
            onNewMatch: { _ in stage = .playing(machine, seed: freshSeed()) },
            onExit: { stage = .index })
    }

    /// The run ended: a fresh table racks at its faceoff — the attract screen
    /// — showing the score, with the pen out if it boarded.
    private func gameOver(_ score: Int, stage runStage: Int?, on machine: ArcadeMachine) {
        lastScore = score
        lastStage = runStage
        pendingScore = board(for: machine).qualifies(score) ? score : nil
        stage = .playing(machine, seed: freshSeed())
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
        _ = signed.submit(name: name, score: score, stage: lastStage)
        setBoard(signed, for: machine)
        pendingScore = nil
    }

    private func board(for machine: ArcadeMachine) -> Hiscores {
        (try? JSONDecoder().decode(Hiscores.self, from: data(for: machine))) ?? Hiscores()
    }

    /// Every machine keeps its OWN board — runs on different tables never
    /// share a ladder.
    private func data(for machine: ArcadeMachine) -> Data {
        switch machine.id {
        case ArcadeSpec.brickWall.id: return brickBoard
        case ArcadeSpec.survival.id: return survivalBoard
        default: return bumperBoard
        }
    }

    private func setBoard(_ board: Hiscores, for machine: ArcadeMachine) {
        let data = (try? JSONEncoder().encode(board)) ?? Data()
        switch machine.id {
        case ArcadeSpec.brickWall.id: brickBoard = data
        case ArcadeSpec.survival.id: survivalBoard = data
        default: bumperBoard = data
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
                VStack(spacing: 10) {
                    ForEach(ArcadeSpec.machines) { machine in
                        machineCard(machine)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
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

    /// One shelf row: the game's square icon on the left — its signature
    /// furniture, unmistakable at a glance — and the words on the right.
    private func machineCard(_ machine: ArcadeMachine) -> some View {
        Button {
            lastScore = nil
            pendingScore = nil
            stage = .playing(machine, seed: freshSeed())
        } label: {
            HStack(spacing: 14) {
                ArcadeIcon(kind: machine.icon)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(machine.title, bundle: .module)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Neon.cyan)
                        .lineLimit(1)
                    if let top = board(for: machine).entries.first {
                        Text(verbatim: "\(top.score) · \(top.name)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Neon.inkSoft)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Neon.inkSoft.opacity(0.4), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func freshSeed() -> UInt64 { UInt64.random(in: 0...UInt64.max) }
}
