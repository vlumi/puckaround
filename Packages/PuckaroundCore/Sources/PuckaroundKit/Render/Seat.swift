import PuckaroundCore
import SwiftUI

/// **Which way a side's labels read.** Labels are laid out head-to-head in the
/// board's own space — the bottom side upright, the top side turned 180°, the
/// pass-and-play layout. The board as a whole then rotates to fill the screen
/// (see `BoardPlacement`), carrying the labels with it, so nothing here needs to
/// know the device orientation.
struct Seat {
    let side: Side

    /// Head-to-head: the top player's labels are upside-down relative to the
    /// bottom player's, so each reads upright from its own end.
    var labelAngle: Angle { .degrees(side == .top ? 180 : 0) }
}
