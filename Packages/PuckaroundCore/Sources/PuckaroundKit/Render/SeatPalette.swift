import PuckaroundCore
import SwiftUI

/// One color per seat — or per team, when the four are paired — distinct from
/// each other and from the ice.
enum SeatPalette {
    static let colors: [Color] = [
        Color(red: 0.86, green: 0.22, blue: 0.20),
        Color(red: 0.16, green: 0.45, blue: 0.86),
        Color(red: 0.95, green: 0.72, blue: 0.10),
        Color(red: 0.18, green: 0.64, blue: 0.34),
    ]

    static func color(for player: PlayerID, in lineup: Lineup) -> Color {
        colors[lineup.team(of: player) ?? player.rawValue]
    }
}
