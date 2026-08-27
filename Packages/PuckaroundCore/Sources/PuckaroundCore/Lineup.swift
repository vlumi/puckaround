/// Which edge of the device a seat plays from. Every player sits at an edge of
/// the shared screen, so this is both a seating position and which wall is
/// "theirs". World space is y-down, so `bottom` is the bottom of the screen.
public enum Edge: CaseIterable, Codable, Sendable {
    case bottom
    case top
    case left
    case right

    /// Unit vector from this edge toward the middle of the table — the seat's
    /// own "forward".
    public var inward: Vec2 {
        switch self {
        case .bottom: return Vec2(0, -1)
        case .top: return Vec2(0, 1)
        case .left: return Vec2(1, 0)
        case .right: return Vec2(-1, 0)
        }
    }
}

/// Who is at the table: 2–4 players, and whether the four are paired up.
///
/// Seats fill in a fixed order — bottom, top, left, right — so two players
/// always face each other across the table, and the third and fourth take the
/// sides. Teams pair partners ACROSS the table (bottom + top vs. left + right).
public struct Lineup: Equatable, Codable, Sendable {
    public static let minPlayers = 2
    public static let maxPlayers = 4
    static let seatOrder: [Edge] = [.bottom, .top, .left, .right]

    public let playerCount: Int
    /// Two teams of two. Only meaningful — and only allowed — with four players.
    public let teamed: Bool

    /// Nil for an impossible table: fewer than two or more than four players,
    /// or teams without exactly four.
    public init?(playerCount: Int, teamed: Bool = false) {
        guard (Lineup.minPlayers...Lineup.maxPlayers).contains(playerCount) else { return nil }
        guard !teamed || playerCount == Lineup.maxPlayers else { return nil }
        self.playerCount = playerCount
        self.teamed = teamed
    }

    /// Two players facing each other — the default table.
    public static let duel = Lineup(playerCount: 2)!

    public var players: [PlayerID] { (0..<playerCount).map { PlayerID($0) } }

    public func contains(_ player: PlayerID) -> Bool {
        (0..<playerCount).contains(player.rawValue)
    }

    public func seat(of player: PlayerID) -> Edge {
        Lineup.seatOrder[player.rawValue]
    }

    /// 0 or 1 when teamed; nil in a free-for-all.
    public func team(of player: PlayerID) -> Int? {
        teamed ? player.rawValue / 2 : nil
    }

    /// A player is always their own ally; otherwise only a teammate is.
    public func areAllies(_ a: PlayerID, _ b: PlayerID) -> Bool {
        if a == b { return true }
        guard let teamA = team(of: a), let teamB = team(of: b) else { return false }
        return teamA == teamB
    }
}
