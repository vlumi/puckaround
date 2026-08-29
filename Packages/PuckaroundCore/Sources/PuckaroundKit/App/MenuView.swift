import PuckaroundCore
import SwiftUI

/// **The front door.** Deliberately small: the wordmark, how many hands each
/// side fields (the format), how many goals win, which puck to play with, and
/// Play. The format is two toggles — one or two hands per side — so singles,
/// 1v2 and doubles are all just a pair of choices.
struct MenuView: View {
    @Binding var pointsToWin: Int
    @Binding var puckShapeKey: String
    @Binding var bottomHands: Int
    @Binding var topHands: Int
    @Binding var wrapWalls: Bool
    let onPlay: () -> Void

    /// The offered targets — a short, sane range.
    private let targets = [3, 5, 7, 11]

    var body: some View {
        ZStack {
            Neon.ground.ignoresSafeArea()
            // A scroll view so a short screen (SE) can reach Play instead of
            // clipping it. The content centers itself when the screen is tall
            // enough (minHeight = the viewport) and scrolls when it isn't.
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 28) {
                        // Spacers center the content on a tall screen but collapse
                        // to nothing when it overflows, so nothing ever clips.
                        Spacer(minLength: 0)
                        wordmark
                        formatPicker
                        firstToPicker
                        puckPicker
                        wallsPicker
                        NeonButton(title: "Play", tint: Neon.cyan, prominent: true, action: onPlay)
                            .padding(.horizontal, 40)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    // Cap the column so buttons don't stretch across an iPad,
                    // then re-expand to the full width so that capped column is
                    // centerd rather than pinned to the leading edge.
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
    }

    /// Solid or wrap side walls — the table variant. Two labeled pills.
    private var wallsPicker: some View {
        VStack(spacing: 12) {
            sectionLabel("Walls")
            HStack(spacing: 10) {
                wallOption("Solid", wrap: false)
                wallOption("Wrap", wrap: true)
            }
        }
    }

    private func wallOption(_ label: LocalizedStringKey, wrap: Bool) -> some View {
        let selected = wrapWalls == wrap
        return Button {
            wrapWalls = wrap
        } label: {
            Text(label, bundle: .module)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Neon.ground : Neon.ink)
                .frame(width: 96, height: 44)
                .background(pillBackground(selected: selected))
        }
        .buttonStyle(.plain)
    }

    /// The two teams face off across a "VS.", each its own color — so it reads
    /// as one side against the other, not a stack of unrelated toggles. Within a
    /// team, 1 or 2 hands (person silhouettes); mixing the two teams is 1v2.
    private var formatPicker: some View {
        VStack(spacing: 12) {
            sectionLabel("Players")
            HStack(spacing: 16) {
                teamColumn(binding: $topHands, tint: Neon.cyan)
                Text("VS.", bundle: .module)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Neon.inkSoft)
                teamColumn(binding: $bottomHands, tint: Neon.magenta)
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

    private var puckPicker: some View {
        VStack(spacing: 12) {
            sectionLabel("Puck")
            HStack(spacing: 10) {
                ForEach(PuckShapeKey.allCases, id: \.rawValue) { key in
                    let selected = key.rawValue == puckShapeKey
                    Button {
                        puckShapeKey = key.rawValue
                    } label: {
                        PuckGlyph(key: key)
                            .frame(width: 30, height: 30)
                            .foregroundStyle(selected ? Neon.ground : Neon.ink)
                            .frame(width: 72, height: 52)
                            .background(pillBackground(selected: selected))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: key.label))
                }
            }
        }
    }

    private var wordmark: some View {
        VStack(spacing: 2) {
            Text("PUCK", bundle: .module)
                .foregroundStyle(Neon.cyan)
                .shadow(color: Neon.cyan.opacity(0.7), radius: 14)
            Text("AROUND", bundle: .module)
                .foregroundStyle(Neon.magenta)
                .shadow(color: Neon.magenta.opacity(0.7), radius: 14)
        }
        .font(.system(size: 54, weight: .black, design: .rounded))
    }

    private var firstToPicker: some View {
        VStack(spacing: 12) {
            sectionLabel("First to")
            HStack(spacing: 10) {
                ForEach(targets, id: \.self) { target in
                    let selected = target == pointsToWin
                    Button {
                        pointsToWin = target
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
private struct PuckGlyph: View {
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
private struct HandsGlyph: View {
    let count: Int

    var body: some View {
        Image(systemName: count == 2 ? "person.2.fill" : "person.fill")
            .resizable()
            .scaledToFit()
            .font(.body.weight(.semibold))
    }
}
