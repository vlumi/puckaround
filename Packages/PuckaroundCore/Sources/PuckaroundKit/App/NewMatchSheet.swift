import PuckaroundCore
import SwiftUI

/// **The "New match" modal**, opened from the front door and from the in-game
/// pause menu. It edits a draft copy of the setup so backing out (the X) leaves
/// the stored setup — and any running game — untouched; only Start commits the
/// draft and launches a fresh match. The one place a match is configured and
/// begun, so the two entry points can't drift.
struct NewMatchSheet: View {
    /// The setup to open on — the stored one, so the pickers show last time's.
    let initial: Setup
    /// Commit the chosen setup and start a match with it.
    let onStart: (Setup) -> Void
    /// Dismiss without starting; the draft is discarded.
    let onClose: () -> Void

    @State private var draft: Setup

    init(initial: Setup, onStart: @escaping (Setup) -> Void, onClose: @escaping () -> Void) {
        self.initial = initial
        self.onStart = onStart
        self.onClose = onClose
        _draft = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea().onTapGesture(perform: onClose)
            // Header and Start are pinned; only the pickers scroll between them,
            // so Start is always in reach — a short screen (SE) never has to
            // scroll to it, and a tall one shows everything at once.
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                ScrollView {
                    SetupControls(setup: $draft)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                }
                start
                    .padding(24)
            }
            .frame(maxWidth: 440)
            .background(card)
            .padding(16)
        }
    }

    /// The title, with the X to back out sitting in the corner beside it.
    private var header: some View {
        ZStack {
            Text("New match", bundle: .module)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Neon.ink)
            HStack {
                Spacer()
                NeonIconButton(systemName: "xmark", label: "Close", action: onClose)
            }
        }
    }

    private var start: some View {
        NeonButton(title: "Start match", tint: Neon.cyan, prominent: true) { onStart(draft) }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 18).fill(Neon.ground.opacity(0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 18).strokeBorder(Neon.inkSoft, lineWidth: 1))
    }
}
