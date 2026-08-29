import PuckaroundCore
import SwiftUI

/// The side colours: neon, and each one owns exactly three things on the table
/// — a side's mallet(s), its goal mouth, and its score. Nothing else wears a
/// side colour, so the table furniture (see `RinkRenderer.ice`/`.line`) stays
/// neutral and neither side "owns" the rink.
///
/// **One colour per side, two on the table:** magenta for the bottom, cyan for
/// the top — the max-contrast pair, and safe under colour blindness (they
/// separate on both lightness and the red–green axis). In doubles both mallets
/// of a side share its colour. Lime and amber are unused now (a side owns its
/// colour, not a seat); they are kept for a possible future many-sided table.
enum SeatPalette {
    static let magenta = Color(red: 1.0, green: 0.18, blue: 0.47)
    static let cyan = Color(red: 0.13, green: 0.88, blue: 1.0)
    static let lime = Color(red: 0.78, green: 1.0, blue: 0.18)
    static let amber = Color(red: 1.0, green: 0.69, blue: 0.13)

    static func color(for side: Side) -> Color {
        side == .bottom ? magenta : cyan
    }
}
