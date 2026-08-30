import PuckaroundCore
import SwiftUI

/// **Which way a side's labels read.**
///
/// - Portrait (`boardTurn == 0`): players sit at the two short ends, head to
///   head — the bottom side upright, the top side turned 180°.
/// - Landscape (a quarter turn): both players sit side by side along the bottom
///   edge, so both sides' labels cancel the turn and read upright the same way,
///   instead of riding the board around to the sides.
/// - Upside down (a half turn): head-to-head again — the flip already puts each
///   player's end at their physical side, so no counter-turn is wanted.
struct Seat {
    let side: Side
    /// The quarter-turn the whole board is drawn with (see `BoardPlacement`).
    var boardTurn: Angle = .degrees(0)

    var labelAngle: Angle {
        // Landscape (a quarter turn): cancel the board turn so both labels read
        // upright from the bottom bench.
        if abs(boardTurn.degrees) == 90 {
            return .degrees(-boardTurn.degrees)
        }
        // Portrait either way up: the classic head-to-head layout — the board's
        // 180° flip already puts each player's end at their physical side.
        return .degrees(side == .top ? 180 : 0)
    }
}
