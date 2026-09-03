import PuckaroundCore
import SwiftUI

/// **The "New match" modal**, opened from the front door and from the in-game
/// pause menu. It edits a draft copy of the setup so backing out (the X) leaves
/// the stored setup — and any running game — untouched; only Start commits the
/// draft and launches a fresh match. The one place a match is configured and
/// begun, so the two entry points can't drift.
struct NewMatchSheet: View {
    /// Commit the chosen setup and start a match with it.
    let onStart: (Setup) -> Void
    /// Dismiss without starting; the draft is discarded.
    let onClose: () -> Void
    /// A practice sheet says so — and hides the Players row, since the
    /// machine's end isn't up for picking.
    let practice: Bool

    @State private var draft: Setup

    /// `initial` seeds the draft — the stored setup, so the pickers show last
    /// time's picks.
    init(
        initial: Setup, practice: Bool = false,
        onStart: @escaping (Setup) -> Void, onClose: @escaping () -> Void
    ) {
        self.onStart = onStart
        self.onClose = onClose
        self.practice = practice
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
                    SetupControls(setup: $draft, showsFormat: !practice)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                }
                start
                    .padding(24)
            }
            .frame(maxWidth: 440)
            .background(NeonCard())
            .padding(16)
        }
    }

    private var header: some View {
        NeonSheetHeader(title: practice ? "New practice" : "New match", onClose: onClose)
    }

    private var start: some View {
        NeonButton(
            title: practice ? "Start practice" : "Start match",
            tint: Neon.cyan, prominent: true
        ) { onStart(draft) }
    }
}
