/// **A player's kits.** Two slots into the neon wardrobe — home and away —
/// carried by a remembered name. Pure identity flair: the name is the only
/// identity, the sim never sees either. The Kit maps slots to actual colors;
/// this side only guarantees the football logic — a clash between two homes
/// switches exactly one side to its away, which is distinct from its own home
/// by construction, so one step always resolves.
public struct PlayerKit: Equatable, Codable, Sendable {
    public var home: Int
    public var away: Int

    /// The wardrobe's size — the Kit's palette carries exactly this many hues.
    public static let paletteCount = 8

    public init(home: Int, away: Int) {
        self.home = home
        self.away = away
    }

    /// The kit a name wears before anyone picks: a stable hash spreads homes
    /// over the palette and the away is the next hue along. FNV-1a rather than
    /// `hashValue`, which is seeded per launch and would reshuffle every kit.
    public static func assigned(to name: String) -> PlayerKit {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in name.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        let home = Int(hash % UInt64(paletteCount))
        return PlayerKit(home: home, away: (home + 1) % paletteCount)
    }

    /// A fresh kit off the rack: random home, random distinct away — and
    /// never the kit it replaces, so a shuffle always visibly shuffles. UI
    /// flair only; nothing random here ever enters the sim.
    public static func random(differingFrom old: PlayerKit? = nil) -> PlayerKit {
        while true {
            let home = Int.random(in: 0..<paletteCount)
            var away = Int.random(in: 0..<paletteCount - 1)
            if away >= home { away += 1 }
            let kit = PlayerKit(home: home, away: away)
            if kit != old { return kit }
        }
    }

    /// The away, guaranteed distinct from the home even if stored data says
    /// otherwise — resolution must never hand both ends one color.
    public var distinctAway: Int {
        away == home ? (home + 1) % Self.paletteCount : away
    }

    /// What each end wears: both homes unless they match — then the home
    /// side keeps its color (the winner-stays incumbent defends their turf;
    /// elsewhere the bottom end) and the other switches to its away.
    public static func resolve(
        bottom: PlayerKit, top: PlayerKit, homeSide: Side = .bottom
    ) -> (bottom: Int, top: Int) {
        guard bottom.home == top.home else { return (bottom.home, top.home) }
        return homeSide == .bottom
            ? (bottom.home, top.distinctAway) : (bottom.distinctAway, top.home)
    }
}
