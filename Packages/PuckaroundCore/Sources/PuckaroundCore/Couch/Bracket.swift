/// **A knockout bracket.** A random draw seats up to 32 players on a
/// power-of-two sheet; when the field doesn't fill it, byes send a random few
/// straight past round one — they simply play one match fewer, the price of an
/// uneven count. Losers are out; the last name standing is the champion. The
/// draw is deterministic from an injected seed, like all randomness here.
public struct Bracket: Equatable, Codable, Sendable {
    /// The sheet, round by round: `rounds[0]` has one slot per entry position
    /// (nil = a bye), each later round half as many, and the last exactly one —
    /// the champion once the final is played. `rounds[k + 1][m]` is the winner
    /// of the match between `rounds[k][2m]` and `rounds[k][2m + 1]`.
    public private(set) var rounds: [[String?]]
    /// The most recent result, for the between-matches banner.
    public private(set) var lastMatch: MatchResult?

    /// Enough that a round-of-32 column still fits a small screen unscrolled.
    public static let maxPlayers = 32

    /// Draws the sheet. Duplicate names collapse to their first entry — a name
    /// is the only identity there is. Fewer than two distinct names is no
    /// bracket, and past `maxPlayers` the first column wouldn't fit a screen.
    public init?(roster: [String], seed: UInt64) {
        var seen = Set<String>()
        let players = roster.filter { seen.insert($0).inserted }
        guard players.count >= 2, players.count <= Bracket.maxPlayers else { return nil }
        var rng = SeededRNG(seed: seed)
        let drawn = players.shuffled(using: &rng)
        let size = Bracket.slotCount(for: drawn.count)
        let byes = size - drawn.count
        // Spread the byes over the sheet (when they're sparse) so free passes
        // don't all bunch at the top; a bye never meets another bye.
        let byeMatches = Set((0..<byes).map { $0 * (size / 2) / max(byes, 1) })
        var first: [String?] = []
        var pool = drawn.makeIterator()
        for match in 0..<(size / 2) {
            first.append(pool.next())
            first.append(byeMatches.contains(match) ? nil : pool.next())
        }
        rounds = [first]
        var count = size / 2
        while count >= 1 {
            rounds.append([String?](repeating: nil, count: count))
            count /= 2
        }
        // A bye's opponent-less player advances before anything is played.
        for match in 0..<(size / 2) where first[2 * match + 1] == nil {
            rounds[1][match] = first[2 * match]
        }
    }

    /// The next match to play, in sheet order — nil once the champion stands.
    public var current: Pairing? {
        located.map { Pairing(bottom: $0.bottom, top: $0.top) }
    }

    /// The last name standing, once the final is played.
    public var champion: String? { rounds[rounds.count - 1][0] }

    /// The current match ended: the given end's player advances by the given
    /// tallies (games in a best-of, points in a single game); the other is out.
    public mutating func recordWin(by side: Side, winnerScore: Int = 0, loserScore: Int = 0) {
        guard let match = located else { return }
        let winner = side == .bottom ? match.bottom : match.top
        let loser = side == .bottom ? match.top : match.bottom
        rounds[match.round + 1][match.index] = winner
        lastMatch = MatchResult(
            winner: winner, loser: loser, winnerScore: winnerScore, loserScore: loserScore)
    }

    /// A playable match's place on the sheet.
    private struct Located {
        let round: Int
        let index: Int
        let bottom: String
        let top: String
    }

    /// Where the next playable match sits: the earliest round's first match with
    /// both players known and no winner yet.
    private var located: Located? {
        for round in 0..<(rounds.count - 1) {
            for match in 0..<rounds[round + 1].count where rounds[round + 1][match] == nil {
                if let a = rounds[round][2 * match], let b = rounds[round][2 * match + 1] {
                    return Located(round: round, index: match, bottom: a, top: b)
                }
            }
        }
        return nil
    }

    /// The smallest power of two holding `players`.
    private static func slotCount(for players: Int) -> Int {
        var size = 2
        while size < players { size *= 2 }
        return size
    }
}
