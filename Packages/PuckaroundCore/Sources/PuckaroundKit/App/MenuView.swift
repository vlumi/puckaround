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
    /// Open the tournament flow (resuming a saved evening if one exists).
    let onTournament: () -> Void
    /// Start practice against the machine, with the current stored setup.
    let onPractice: () -> Void
    /// Open the arcade shelf — solo minigames and their boards.
    let onArcade: () -> Void

    @State private var showingNewMatch = false
    @State private var showingPractice = false

    var body: some View {
        ZStack {
            Neon.ground.ignoresSafeArea()
            VStack(spacing: 40) {
                wordmark
                VStack(spacing: 14) {
                    NeonButton(title: "New match", tint: Neon.cyan, prominent: true) {
                        showingNewMatch = true
                    }
                    NeonButton(title: "Tournament", action: onTournament)
                    NeonButton(title: "Practice") { showingPractice = true }
                    NeonButton(title: "Arcade", action: onArcade)
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
            if showingPractice {
                NewMatchSheet(
                    initial: setup, practice: true,
                    onStart: { chosen in
                        setup = chosen
                        showingPractice = false
                        onPractice()
                    },
                    onClose: { showingPractice = false })
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
