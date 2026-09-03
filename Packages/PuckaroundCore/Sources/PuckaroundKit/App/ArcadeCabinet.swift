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
    /// The stage the boarding run died on, shown under its score.
    let pendingStage: Int?
    let onSign: (String) -> Void
    let onSkip: () -> Void

    @State private var newName = ""
    @FocusState private var signFocused: Bool

    var body: some View {
        GeometryReader { geo in
            // Where the playfield actually sits: portrait letterboxes a
            // width-fit 100×160 board, and the overlay lays out around it.
            let fieldTop = max(0, (geo.size.height - geo.size.width * 1.6) / 2)
            let fieldHeight = geo.size.width * 1.6
            ZStack {
                // While the pen is out nothing competes with it: no board in
                // the background, just the field.
                if pendingScore == nil {
                    // The board holds ONE place — inside the field, below the
                    // goal and its guardian furniture — whether or not a last
                    // run shows. Sheer, with dark-glowing text: the field
                    // stays visible through it. It carries no controls, so it
                    // takes no touches — the center-ring menu works through it.
                    VStack(spacing: 0) {
                        Spacer().frame(height: fieldTop + fieldHeight * 0.17)
                        card(opacity: 0.55) {
                            boardRows
                                .shadow(color: Neon.ground.opacity(0.9), radius: 2)
                        }
                        .frame(maxWidth: 280)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                    // The last run takes the letterbox band above the field.
                    if let lastScore {
                        VStack(spacing: 0) {
                            card(opacity: 0.7, pad: 8) { lastRun(lastScore) }
                                .frame(maxWidth: 220)
                                .frame(height: max(fieldTop, 56))
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                }
                // The pen demands the middle of the screen, fully solid — and
                // it leaves the moment a name lands, handing back the field.
                if let pendingScore {
                    card(opacity: 1) { signSection(pendingScore) }
                        .frame(maxWidth: 300)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        }
    }

    /// A pane over the table: `opacity` sets how much field shows through.
    private func card(
        opacity: Double = 0.94, pad: CGFloat = 14, @ViewBuilder body: () -> some View
    ) -> some View {
        VStack(spacing: 8, content: body)
            .padding(pad)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Neon.ground.opacity(opacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Neon.inkSoft.opacity(0.25), lineWidth: 1)))
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
                    if let stage = entry.stage {
                        Text(verbatim: "S\(stage)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Neon.inkSoft.opacity(0.8))
                            .monospacedDigit()
                    }
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

    /// The last run's score when it didn't board — one compact row, sized for
    /// the letterbox band above the field.
    private func lastRun(_ score: Int) -> some View {
        HStack(spacing: 10) {
            caption("Last run")
            Text(verbatim: "\(score)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Neon.cyan)
                .monospacedDigit()
                .shadow(color: Neon.cyan.opacity(0.6), radius: 6)
        }
    }

    /// A boarded run waits for its name: one tap on a pool chip signs it, or
    /// a new name types in — joining the pool like anywhere else.
    @ViewBuilder
    private func signSection(_ score: Int) -> some View {
        caption("Sign the board")
        scoreText(score)
        if let pendingStage {
            Text("Stage \(pendingStage)", bundle: .module)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Neon.inkSoft)
        }
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
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    SeatPalette.neon(player.kit.home).opacity(0.5),
                                    lineWidth: 1.5)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The pen itself, dressed to be seen — a dim outline under a row of
    /// glowing chips was invisible exactly when the pane was asking for it.
    /// It wears the board's cyan with a signature mark, and with no chips to
    /// tap it takes focus itself, keyboard ready.
    private var signField: some View {
        HStack(spacing: 10) {
            Image(systemName: "signature")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Neon.cyan)
            TextField(text: $newName, prompt: Text("Your name", bundle: .module)) {
                Text("Your name", bundle: .module)
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(Neon.ink)
            .textFieldStyle(.plain)
            .submitLabel(.done)
            .focused($signFocused)
            .onSubmit {
                let name = newName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, name.count <= RosterSheet.maxNameLength else { return }
                newName = ""
                onSign(name)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Neon.cyan.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Neon.cyan.opacity(0.7), lineWidth: 1.5))
        )
        .onAppear {
            if pool.isEmpty { signFocused = true }
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

/// A cabinet's square icon: a close-up of its signature furniture, drawn in
/// the table's own materials — one glowing bumper, a staggered course of
/// bricks, a hail of pucks. What you'll play, at a glance.
struct ArcadeIcon: View {
    enum Kind {
        case bumper
        case bricks
        case pucks
    }

    let kind: Kind

    var body: some View {
        Canvas { context, size in
            let s = size.width
            let frame = Path(
                roundedRect: CGRect(origin: .zero, size: size), cornerRadius: s * 0.18)
            context.fill(frame, with: .color(RinkRenderer.ice))
            context.clip(to: frame)
            switch kind {
            case .bumper: drawBumper(&context, s)
            case .bricks: drawBricks(&context, s)
            case .pucks: drawPucks(&context, s)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func drawBumper(_ context: inout GraphicsContext, _ s: CGFloat) {
        let ring = Path(ellipseIn: CGRect(x: s * 0.2, y: s * 0.2, width: s * 0.6, height: s * 0.6))
        context.fill(ring, with: .color(RinkRenderer.line.opacity(0.08)))
        RinkRenderer.glowStroke(
            ring, color: RinkRenderer.line.opacity(0.85), lineWidth: max(1.5, s * 0.045),
            blur: s * 0.09, in: &context)
        let hub = Path(
            ellipseIn: CGRect(x: s * 0.42, y: s * 0.42, width: s * 0.16, height: s * 0.16))
        context.fill(hub, with: .color(RinkRenderer.line.opacity(0.5)))
    }

    private func drawBricks(_ context: inout GraphicsContext, _ s: CGFloat) {
        // Two staggered courses, the outer bricks running off the frame — a
        // close-up of a wall, not a diagram of one.
        let rows: [(y: CGFloat, xs: [CGFloat])] = [
            (0.24, [0.10, 0.54]), (0.46, [-0.12, 0.32, 0.76]), (0.68, [0.10, 0.54]),
        ]
        for row in rows {
            for x in row.xs {
                let brick = Path(
                    roundedRect: CGRect(x: x * s, y: row.y * s, width: s * 0.4, height: s * 0.17),
                    cornerRadius: s * 0.03)
                context.fill(brick, with: .color(RinkRenderer.line.opacity(0.12)))
                RinkRenderer.glowStroke(
                    brick, color: RinkRenderer.line.opacity(0.55), lineWidth: max(1, s * 0.02),
                    blur: s * 0.05, in: &context)
            }
        }
    }

    private func drawPucks(_ context: inout GraphicsContext, _ s: CGFloat) {
        // A hail of white-hot pucks, trails saying they're all incoming.
        let pucks: [(center: CGPoint, r: CGFloat)] = [
            (CGPoint(x: 0.30, y: 0.26), 0.10), (CGPoint(x: 0.70, y: 0.42), 0.12),
            (CGPoint(x: 0.42, y: 0.70), 0.14),
        ]
        for puck in pucks {
            for ghost in stride(from: 3, through: 1, by: -1) {
                let offset = CGFloat(ghost) * puck.r * 0.9
                let trail = Path(
                    ellipseIn: CGRect(
                        x: (puck.center.x - puck.r) * s + offset * s * 0.3,
                        y: (puck.center.y - puck.r) * s - offset * s,
                        width: puck.r * 2 * s, height: puck.r * 2 * s))
                context.fill(
                    trail, with: .color(RinkRenderer.puck.opacity(0.10 / CGFloat(ghost))))
            }
            let core = Path(
                ellipseIn: CGRect(
                    x: (puck.center.x - puck.r) * s, y: (puck.center.y - puck.r) * s,
                    width: puck.r * 2 * s, height: puck.r * 2 * s))
            RinkRenderer.glow(core, color: RinkRenderer.puck, blur: s * 0.06, in: &context)
        }
    }
}
