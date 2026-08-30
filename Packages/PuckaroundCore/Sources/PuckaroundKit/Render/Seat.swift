import PuckaroundCore
import SwiftUI

/// **Which way a side's labels read.**
///
/// - Portrait (`boardTurn == 0`): players sit at the two short ends, head to
///   head — the bottom side upright, the top side turned 180°.
/// - Landscape: the board is turned a quarter to fill the screen, and both
///   players sit side by side along the bottom edge. So both sides' labels are
///   counter-turned by the board's own rotation — they end up upright on screen,
///   reading the same way, instead of riding the board around to the sides.
struct Seat {
    let side: Side
    /// The quarter-turn the whole board is drawn with (see `BoardPlacement`).
    var boardTurn: Angle = .degrees(0)

    var labelAngle: Angle {
        // Landscape: cancel the board turn so both labels read upright, bottom.
        if boardTurn.degrees != 0 {
            return .degrees(-boardTurn.degrees)
        }
        // Portrait: the classic head-to-head layout.
        return .degrees(side == .top ? 180 : 0)
    }
}
