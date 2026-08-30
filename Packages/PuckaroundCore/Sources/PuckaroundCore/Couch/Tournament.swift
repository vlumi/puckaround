/// **Winner stays.** A line of named players sharing one table: two are on it,
/// the rest wait. The winner keeps their end, the loser rejoins the back of the
/// line, and the line's front takes the vacated end — the classic couch
/// tournament, any player count, no fixed length. Names are labels for tonight,
/// not profiles: the tally lives only as long as the tournament does. The sim
/// below never sees a name (see `MalletSlot` — identity ends at the table).
public struct Tournament: Equatable, Codable, Sendable {
    /// One row of tonight's tally.
    public struct Standing: Equatable, Codable, Sendable {
        public let name: String
        public let wins: Int
    }

    /// Who defends the bottom end right now.
    public private(set) var bottom: String
    /// Who defends the top end right now.
    public private(set) var top: String
    /// Waiting players, next to play first.
    public private(set) var line: [String]
    /// Matches won tonight, by name.
    public private(set) var wins: [String: Int]
    /// Who won last, and how many in a row — the current hold on the table.
    public private(set) var streakName: String?
    public private(set) var streak = 0
    /// Tonight's longest run and whose it is (the first to reach it keeps it).
    public private(set) var bestStreak = 0
    public private(set) var bestStreakName: String?

    /// The first two names take the table (first at the bottom), the rest form
    /// the line in roster order. Duplicate names collapse to their first entry —
    /// a name is the only identity there is. Fewer than two distinct names is no
    /// tournament at all.
    public init?(roster: [String]) {
        var seen = Set<String>()
        let players = roster.filter { seen.insert($0).inserted }
        guard players.count >= 2 else { return nil }
        bottom = players[0]
        top = players[1]
        line = Array(players.dropFirst(2))
        wins = Dictionary(uniqueKeysWithValues: players.map { ($0, 0) })
    }

    /// Everyone in tonight's tournament, in no particular order.
    public var players: [String] { Array(wins.keys) }

    /// Who plays the loser of the current match — nil with two players, where
    /// the same pair just goes again.
    public var upNext: String? { line.first }

    /// The match ended: the given end won. The winner stays put, the loser goes
    /// to the back of the line, and the line's front takes over the loser's end.
    public mutating func recordWin(by side: Side) {
        let winner = side == .bottom ? bottom : top
        wins[winner, default: 0] += 1
        streak = winner == streakName ? streak + 1 : 1
        streakName = winner
        if streak > bestStreak {
            bestStreak = streak
            bestStreakName = winner
        }
        guard let next = line.first else { return }
        let loser = side == .bottom ? top : bottom
        line.removeFirst()
        line.append(loser)
        if side == .bottom { top = next } else { bottom = next }
    }

    /// Tonight's tally, most wins first; ties break by name so the order is
    /// stable frame to frame.
    public var standings: [Standing] {
        wins.map { Standing(name: $0.key, wins: $0.value) }
            .sorted { ($0.wins, $1.name) > ($1.wins, $0.name) }
    }
}
