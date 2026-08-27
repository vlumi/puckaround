@testable import PuckaroundCore

/// Test-only ways to stage a rink: put the puck somewhere, put a mallet
/// somewhere, get the mallets out of the way. Production code never places
/// anything by hand — the sim moves everything.
extension Rink {
    mutating func place(_ puck: Puck) {
        setPuckForTesting(puck)
    }

    mutating func placeMallet(of player: PlayerID, at position: Vec2) {
        setMalletForTesting(Mallet(position: position), of: player)
    }

    /// Mallets into their far goal-side corners, clear of the centre.
    mutating func park() {
        for player in lineup.players {
            let zone = table.malletZone(for: lineup.seat(of: player))
            let y = lineup.seat(of: player) == .top ? zone.minY : zone.maxY
            placeMallet(of: player, at: Vec2(zone.minX, y))
        }
    }
}
