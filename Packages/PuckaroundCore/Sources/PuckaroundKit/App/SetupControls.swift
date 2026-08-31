import PuckaroundCore
import SwiftUI

/// **The setup pickers**: players, first-to, match length, puck (with a "?" for
/// random) and walls (likewise). Bound to a `Setup` value; the New match modal
/// points them at a discardable draft. One picker set, used wherever a match is
/// configured.
struct SetupControls: View {
    @Binding var setup: Setup
    /// The tournament sheet hides the players picker — a winner-stays pairing is
    /// two people, so its matches are always one-on-one.
    var showsFormat = true

    /// The offered points-per-game targets — a short, sane range.
    private let targets = [3, 5, 7, 11]
    /// Match length as games-to-win, and the label for each.
    private let matchLengths: [(games: Int, label: LocalizedStringKey)] = [
        (1, "Single"), (2, "Best of 3"), (3, "Best of 5"),
    ]

    var body: some View {
        VStack(spacing: 28) {
            if showsFormat {
                formatPicker
            }
            firstToPicker
            matchPicker
            puckPicker
            countPicker
            wallsPicker
        }
    }

    /// How many pucks fly at once, plus a "?" that rolls 1–3 each game.
    private var countPicker: some View {
        VStack(spacing: 12) {
            sectionLabel("Pucks")
            HStack(spacing: 10) {
                ForEach(1...3, id: \.self) { count in
                    let selected = !setup.randomPuckCount && count == setup.puckCount
                    Button {
                        setup.puckCount = count
                        setup.randomPuckCount = false
                    } label: {
                        Text(verbatim: "\(count)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(selected ? Neon.ground : Neon.ink)
                            .frame(width: 52, height: 48)
                            .background(pillBackground(selected: selected))
                    }
                    .buttonStyle(.plain)
                }
                randomPill(selected: setup.randomPuckCount, width: 52) {
                    setup.randomPuckCount = true
                }
                .accessibilityLabel(Text(verbatim: "Random puck count"))
            }
        }
    }

    /// The two teams face off across a "VS.", each its own color — so it reads
    /// as one side against the other, not a stack of unrelated toggles. Within a
    /// team, 1 or 2 hands (person silhouettes); mixing the two teams is 1v2.
    private var formatPicker: some View {
        VStack(spacing: 12) {
            sectionLabel("Players")
            HStack(spacing: 16) {
                teamColumn(binding: $setup.topHands, tint: Neon.cyan)
                Text("VS.", bundle: .module)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Neon.inkSoft)
                teamColumn(binding: $setup.bottomHands, tint: Neon.magenta)
            }
        }
    }

    /// One team's choice: 1 or 2 hands, the two options stacked, the picked one
    /// filled in the team's color.
    private func teamColumn(binding: Binding<Int>, tint: Color) -> some View {
        VStack(spacing: 8) {
            ForEach([1, 2], id: \.self) { count in
                let selected = count == binding.wrappedValue
                Button {
                    binding.wrappedValue = count
                } label: {
                    HandsGlyph(count: count)
                        .frame(height: 24)
                        .foregroundStyle(selected ? Neon.ground : tint)
                        .frame(width: 104, height: 44)
                        .background(pillBackground(selected: selected, tint: tint))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: count == 1 ? "1 player" : "2 players"))
            }
        }
    }

    private var firstToPicker: some View {
        VStack(spacing: 12) {
            sectionLabel("First to")
            HStack(spacing: 10) {
                ForEach(targets, id: \.self) { target in
                    let selected = target == setup.pointsToWin
                    Button {
                        setup.pointsToWin = target
                    } label: {
                        Text(verbatim: "\(target)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(selected ? Neon.ground : Neon.ink)
                            .frame(width: 52, height: 48)
                            .background(pillBackground(selected: selected))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Single game, or a best-of match. Labeled pills like the other pickers.
    private var matchPicker: some View {
        VStack(spacing: 12) {
            sectionLabel("Match")
            HStack(spacing: 10) {
                ForEach(matchLengths, id: \.games) { length in
                    let selected = length.games == setup.gamesToWin
                    Button {
                        setup.gamesToWin = length.games
                    } label: {
                        Text(length.label, bundle: .module)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(selected ? Neon.ground : Neon.ink)
                            .frame(width: 88, height: 44)
                            .background(pillBackground(selected: selected))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// The three shapes plus a "?" that rolls one each game. Selecting a shape
    /// turns "?" off; selecting "?" leaves the last shape stored to fall back to.
    private var puckPicker: some View {
        VStack(spacing: 12) {
            sectionLabel("Puck")
            HStack(spacing: 10) {
                ForEach(PuckShapeKey.allCases, id: \.rawValue) { key in
                    let selected = !setup.randomPuck && key.rawValue == setup.puckShapeKey
                    Button {
                        setup.puckShapeKey = key.rawValue
                        setup.randomPuck = false
                    } label: {
                        PuckGlyph(key: key)
                            .frame(width: 30, height: 30)
                            .foregroundStyle(selected ? Neon.ground : Neon.ink)
                            .frame(width: 62, height: 52)
                            .background(pillBackground(selected: selected))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: key.label))
                }
                randomPill(selected: setup.randomPuck, width: 62) { setup.randomPuck = true }
                    .accessibilityLabel(Text(verbatim: "Random puck"))
            }
        }
    }

    /// Solid or wrap side walls, plus a "?" that flips a coin each game.
    private var wallsPicker: some View {
        VStack(spacing: 12) {
            sectionLabel("Walls")
            HStack(spacing: 10) {
                wallOption("Solid", wrap: false)
                wallOption("Wrap", wrap: true)
                randomPill(selected: setup.randomWalls, width: 72) { setup.randomWalls = true }
                    .accessibilityLabel(Text(verbatim: "Random walls"))
            }
        }
    }

    private func wallOption(_ label: LocalizedStringKey, wrap: Bool) -> some View {
        let selected = !setup.randomWalls && setup.wrapWalls == wrap
        return Button {
            setup.wrapWalls = wrap
            setup.randomWalls = false
        } label: {
            Text(label, bundle: .module)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Neon.ground : Neon.ink)
                .frame(width: 84, height: 44)
                .background(pillBackground(selected: selected))
        }
        .buttonStyle(.plain)
    }

    /// The "?" pill shared by the puck and walls pickers — a random pick.
    private func randomPill(selected: Bool, width: CGFloat, act: @escaping () -> Void)
        -> some View
    {
        Button(action: act) {
            Text(verbatim: "?")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(selected ? Neon.ground : Neon.ink)
                .frame(width: width, height: 52)
                .background(pillBackground(selected: selected))
        }
        .buttonStyle(.plain)
    }

    /// A section's uppercase, kerned heading — the one label style the pickers
    /// share.
    private func sectionLabel(_ key: LocalizedStringKey) -> some View {
        Text(key, bundle: .module)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Neon.inkSoft)
            .textCase(.uppercase)
            .kerning(2)
    }

    /// The pill behind a picker option: filled when selected, outlined when not.
    /// `tint` colors it (defaulting to neutral ink for the mono pickers).
    private func pillBackground(selected: Bool, tint: Color = Neon.ink) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(selected ? tint : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tint.opacity(selected ? 1 : 0.4), lineWidth: 1.5))
    }
}

/// A tiny outline of a puck shape, for the picker.
struct PuckGlyph: View {
    let key: PuckShapeKey

    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            path(radius: r, center: c)
                .fill(.tint)
        }
    }

    private func path(radius r: CGFloat, center c: CGPoint) -> Path {
        var path = Path()
        switch key {
        case .circle:
            path.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        case .square, .triangle:
            let sides = key == .square ? 4 : 3
            for i in 0..<sides {
                let a = -CGFloat.pi / 2 + 2 * .pi * CGFloat(i) / CGFloat(sides)
                let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
        return path
    }
}

/// One or two person silhouettes — a side's hand count. SF Symbols carry the
/// shape (this is UI chrome, not the procedural rink), so one and two read at a
/// glance and tint with selection.
struct HandsGlyph: View {
    let count: Int

    var body: some View {
        Image(systemName: count == 2 ? "person.2.fill" : "person.fill")
            .resizable()
            .scaledToFit()
            .font(.body.weight(.semibold))
    }
}
