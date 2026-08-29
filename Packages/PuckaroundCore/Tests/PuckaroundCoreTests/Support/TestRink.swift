@testable import PuckaroundCore

/// Test-only ways to stage a rink: put the puck somewhere, put a mallet
/// somewhere, get the mallets out of the way. Production code never places
/// anything by hand — the sim moves everything.
extension Rink {
    mutating func place(_ puck: Puck) {
        setPuckForTesting(puck)
    }

    mutating func placeMallet(at slot: MalletSlot, position: Vec2) {
        setMalletForTesting(Mallet(position: position), at: slot)
    }

    /// Mallets into their far goal-side corners, clear of the centre.
    mutating func park() {
        for slot in slots {
            let zone = table.malletZone(for: slot)
            let y = slot.side == .top ? zone.minY : zone.maxY
            placeMallet(at: slot, position: Vec2(zone.minX, y))
        }
    }

    /// Skip the faceoff: ready every mallet so the rink is in play. Most sim
    /// tests exercise play, not the opening ceremony (which has its own suite).
    mutating func startPlaying() {
        for slot in slots {
            ready(slot)
        }
    }

    /// A rink already in play, mallets parked out of the way. The common
    /// starting point for the physics/scoring suites.
    static func inPlay(table: Playfield = .duel, seed: UInt64 = 1) -> Rink {
        var r = Rink(table: table, seed: seed)
        r.startPlaying()
        r.park()
        return r
    }
}

extension MalletSlot {
    /// The two singles slots, by side — the common pair a 1v1 test drives.
    static let bottomSingle = MalletSlot(side: .bottom, lane: .full)
    static let topSingle = MalletSlot(side: .top, lane: .full)
}
