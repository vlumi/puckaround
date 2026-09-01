import PuckaroundCore
import SwiftUI

/// The side colors: neon, and each one owns exactly three things on the table
/// — a side's mallet(s), its goal mouth, and its score. Nothing else wears a
/// side color, so the table furniture (see `RinkRenderer.ice`/`.line`) stays
/// neutral and neither side "owns" the rink.
///
/// **One color per side, two on the table.** Nameless play wears the classic
/// pair — magenta bottom, cyan top, max-contrast and safe under color
/// blindness. Named play (tournaments) dresses each end in its player's kit
/// from the wardrobe below, already clash-resolved (`PlayerKit.resolve`), so
/// the pair on the table is always distinct. In doubles both mallets of a
/// side share its color.
enum SeatPalette {
    /// The traditional pair — wardrobe slots 0 and 1, the nameless default.
    static let magenta = palette[0]
    static let cyan = palette[1]

    /// The wardrobe: the traditional neons a `PlayerKit` indexes into (its
    /// `paletteCount` and this count must agree). Curated against the
    /// surroundings — every hue reads on the dark ground, over the grid and
    /// beside the white-hot puck; telling players apart is positional, so
    /// pair contrast is a nice-to-have, not a gate.
    static let palette: [Color] = [
        Color(red: 1.0, green: 0.18, blue: 0.47),  // magenta
        Color(red: 0.13, green: 0.88, blue: 1.0),  // cyan
        Color(red: 0.55, green: 1.0, blue: 0.25),  // lime
        Color(red: 1.0, green: 0.62, blue: 0.10),  // amber
        Color(red: 1.0, green: 0.90, blue: 0.20),  // yellow
        Color(red: 0.70, green: 0.45, blue: 1.0),  // violet
        Color(red: 1.0, green: 0.28, blue: 0.22),  // red
        Color(red: 0.15, green: 0.95, blue: 0.65),  // mint
    ]

    /// The color a wardrobe slot maps to; any Int is safe (indices wrap).
    static func neon(_ slot: Int) -> Color {
        let count = palette.count
        return palette[((slot % count) + count) % count]
    }

    static func color(for side: Side) -> Color {
        side == .bottom ? magenta : cyan
    }
}
