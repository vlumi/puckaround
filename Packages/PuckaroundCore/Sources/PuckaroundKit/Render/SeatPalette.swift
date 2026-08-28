import PuckaroundCore
import SwiftUI

/// The seat colours: neon, and each one owns exactly three things on the table
/// — a player's mallet, their goal mouth, and their score. Nothing else wears a
/// seat colour, so the table furniture (see `RinkRenderer.ice`/`.line`) stays
/// neutral and neither player "owns" the rink.
///
/// **Magenta and cyan lead** for the 1v1 game: the max-contrast pair, and safe
/// under colour blindness (they separate on both lightness and the red–green
/// axis). Lime and amber fill the third and fourth seats for when a four-seat
/// table exists; they are picked to stay distinct from the first two and each
/// other.
enum SeatPalette {
    static let magenta = Color(red: 1.0, green: 0.18, blue: 0.47)
    static let cyan = Color(red: 0.13, green: 0.88, blue: 1.0)
    static let lime = Color(red: 0.78, green: 1.0, blue: 0.18)
    static let amber = Color(red: 1.0, green: 0.69, blue: 0.13)

    static let colors: [Color] = [magenta, cyan, lime, amber]

    static func color(for player: PlayerID, in lineup: Lineup) -> Color {
        colors[lineup.team(of: player) ?? player.rawValue]
    }
}
