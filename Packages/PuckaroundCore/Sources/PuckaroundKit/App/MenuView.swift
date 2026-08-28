import PuckaroundCore
import SwiftUI

/// **The front door.** For a 1v1-only game today it is deliberately small: the
/// wordmark, how many goals win, and Play. No player list, seat picker or mode
/// switch — those arrive with more seats and modes, and scaffolding them now
/// would be chrome for nothing.
struct MenuView: View {
    @Binding var pointsToWin: Int
    let onPlay: () -> Void

    /// The offered targets — a short, sane range.
    private let targets = [3, 5, 7, 11]

    var body: some View {
        ZStack {
            Neon.ground.ignoresSafeArea()
            VStack(spacing: 44) {
                Spacer()
                wordmark
                Spacer()
                firstToPicker
                NeonButton(title: "Play", tint: Neon.cyan, prominent: true, action: onPlay)
                    .padding(.horizontal, 40)
                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 440)
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
