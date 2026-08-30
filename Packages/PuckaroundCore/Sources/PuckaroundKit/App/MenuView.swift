import PuckaroundCore
import SwiftUI

/// **The front door.** The wordmark, the setup pickers (players, first-to,
/// match, puck, walls — see `SetupControls`), and Play. Deliberately small; the
/// same controls back the in-game settings sheet, so the two never drift.
struct MenuView: View {
    let settings: GameSettings
    let onPlay: () -> Void

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
                        SetupControls(settings: settings)
                        NeonButton(title: "Play", tint: Neon.cyan, prominent: true, action: onPlay)
                            .padding(.horizontal, 40)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    // Cap the column so buttons don't stretch across an iPad,
                    // then re-expand to the full width so that capped column is
                    // centered rather than pinned to the leading edge.
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
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
}
