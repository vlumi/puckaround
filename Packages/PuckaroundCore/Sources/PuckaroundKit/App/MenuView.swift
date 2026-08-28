import PuckaroundCore
import SwiftUI

/// **The front door.** For a 1v1-only game today it is deliberately small: the
/// wordmark, how many goals win, which puck to play with, and Play. No player
/// list or seat picker — those arrive with more seats.
struct MenuView: View {
    @Binding var pointsToWin: Int
    @Binding var puckShapeKey: String
    let onPlay: () -> Void

    /// The offered targets — a short, sane range.
    private let targets = [3, 5, 7, 11]

    var body: some View {
        ZStack {
            Neon.ground.ignoresSafeArea()
            VStack(spacing: 36) {
                Spacer()
                wordmark
                Spacer()
                firstToPicker
                puckPicker
                NeonButton(title: "Play", tint: Neon.cyan, prominent: true, action: onPlay)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 440)
        }
    }

    private var puckPicker: some View {
        VStack(spacing: 12) {
            Text("Puck", bundle: .module)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Neon.inkSoft)
                .textCase(.uppercase)
                .kerning(2)
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
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selected ? Neon.ink : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(
                                                Neon.ink.opacity(selected ? 1 : 0.4), lineWidth: 1.5
                                            )))
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
            Text("First to", bundle: .module)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Neon.inkSoft)
                .textCase(.uppercase)
                .kerning(2)
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
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selected ? Neon.ink : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(
                                                Neon.ink.opacity(selected ? 1 : 0.4), lineWidth: 1.5
                                            )))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
