import PuckaroundCore
import SwiftUI

/// **The front door.** Deliberately bare now: the wordmark and one button that
/// opens the New match modal (`NewMatchSheet`), where the setup is chosen and
/// the match begun. The same modal backs the in-game pause menu, so setting up
/// a match is one flow wherever you start it.
struct MenuView: View {
    @Binding var setup: Setup
    /// Start a match with the current stored setup.
    let onPlay: () -> Void

    @State private var showingNewMatch = false

    var body: some View {
        ZStack {
            Neon.ground.ignoresSafeArea()
            VStack(spacing: 40) {
                wordmark
                NeonButton(title: "New match", tint: Neon.cyan, prominent: true) {
                    showingNewMatch = true
                }
                .frame(maxWidth: 280)
                .padding(.horizontal, 40)
            }
            .padding(24)
            if showingNewMatch {
                NewMatchSheet(
                    initial: setup,
                    onStart: { chosen in
                        setup = chosen
                        showingNewMatch = false
                        onPlay()
                    },
                    onClose: { showingNewMatch = false })
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
