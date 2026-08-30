import PuckaroundCore
import SwiftUI

/// The side colors: neon, and each one owns exactly three things on the table
/// — a side's mallet(s), its goal mouth, and its score. Nothing else wears a
/// side color, so the table furniture (see `RinkRenderer.ice`/`.line`) stays
/// neutral and neither side "owns" the rink.
///
/// **One color per side, two on the table:** magenta for the bottom, cyan for
/// the top — the max-contrast pair, and safe under color blindness (they
/// separate on both lightness and the red–green axis). In doubles both mallets
/// of a side share its color.
enum SeatPalette {
    static let magenta = Color(red: 1.0, green: 0.18, blue: 0.47)
    static let cyan = Color(red: 0.13, green: 0.88, blue: 1.0)

    static func color(for side: Side) -> Color {
        side == .bottom ? magenta : cyan
    }
}
