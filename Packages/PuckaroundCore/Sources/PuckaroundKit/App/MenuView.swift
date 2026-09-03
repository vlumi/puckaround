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

    /// The setup modal in flight, if any — one sheet, two doors: a match or a
    /// practice differ only in the flag and which start they fire.
    private enum SetupKind {
        case match
        case practice
    }

    @State private var settingUp: SetupKind?
    @State private var showingSettings = false
    @State private var showingAbout = false

    var body: some View {
        ZStack {
            Neon.ground.ignoresSafeArea()
            // A sideways phone is shorter than this stack — scroll there,
            // stay centered wherever it fits.
            ViewThatFits(in: .vertical) {
                menu
                ScrollView(showsIndicators: false) { menu }
            }
            // The app's own corners: About and Settings, the sibling apps'
            // pattern — never match settings, which live in New match.
            VStack {
                HStack(spacing: 6) {
                    Spacer()
                    NeonIconButton(systemName: "info", label: "About") { showingAbout = true }
                    NeonIconButton(systemName: "gearshape", label: "Settings") {
                        showingSettings = true
                    }
                }
                Spacer()
            }
            .padding(16)
            if let kind = settingUp {
                NewMatchSheet(
                    initial: setup, practice: kind == .practice,
                    onStart: { chosen in
                        setup = chosen
                        settingUp = nil
                        if kind == .practice {
                            onPractice()
                        } else {
                            onPlay()
                        }
                    },
                    onClose: { settingUp = nil })
            }
            if showingSettings {
                SettingsSheet(onClose: { showingSettings = false })
            }
            if showingAbout {
                AboutSheet(onClose: { showingAbout = false })
            }
        }
    }

    /// The wordmark over the mode buttons — the whole front door.
    private var menu: some View {
        VStack(spacing: 32) {
            wordmark
            // The modes read by who they're for: the couch, then one pair
            // of hands — so the solo shelf is easy to spot.
            VStack(spacing: 24) {
                group("Together") {
                    NeonButton(title: "New match", tint: Neon.cyan, prominent: true) {
                        settingUp = .match
                    }
                    NeonButton(title: "Tournament", action: onTournament)
                }
                group("Solo") {
                    NeonButton(title: "Practice") { settingUp = .practice }
                    NeonButton(title: "Arcade", action: onArcade)
                }
            }
            .frame(maxWidth: 280)
            .padding(.horizontal, 40)
        }
        .padding(24)
    }

    /// A captioned cluster of modes, in the sheets' small-caps caption style.
    private func group(
        _ key: LocalizedStringKey, @ViewBuilder body: () -> some View
    ) -> some View {
        VStack(spacing: 12) {
            NeonCaption(title: key)
            body()
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
