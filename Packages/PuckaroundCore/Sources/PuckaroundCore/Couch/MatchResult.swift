/// How a finished match ended — games in a best-of, points in a single game.
/// The between-matches banner shows it, whatever shape the tournament takes.
public struct MatchResult: Equatable, Codable, Sendable {
    public let winner: String
    public let loser: String
    public let winnerScore: Int
    public let loserScore: Int
}

/// Who takes the table, by the end they defend. Codable because a league
/// season persists its whole schedule of these.
public struct Pairing: Equatable, Codable, Sendable {
    public let bottom: String
    public let top: String

    /// The same two with the ends swapped — a return leg.
    public var mirrored: Pairing { Pairing(bottom: top, top: bottom) }
}
