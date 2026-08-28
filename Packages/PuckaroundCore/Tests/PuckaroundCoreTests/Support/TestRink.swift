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

    /// Skip the faceoff: ready every seat so the rink is in play. Most sim tests
    /// exercise play, not the opening ceremony (which has its own suite).
    mutating func startPlaying() {
        for player in lineup.players {
            ready(player)
        }
    }

    /// A rink already in play, mallets parked out of the way. The common
    /// starting point for the physics/scoring suites.
    static func inPlay(table: Playfield = .duel, seed: UInt64 = 1) -> Rink {
        var r = Rink(table: table, lineup: .duel, seed: seed)
        r.startPlaying()
        r.park()
        return r
    }
}
