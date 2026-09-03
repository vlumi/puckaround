/// **A league season.** Everyone plays everyone once or twice, round-robin;
/// standings are by wins — no goal-difference arithmetic. If the top ends
/// tied, two contenders are separated by their own head-to-head first, and
/// only a split (or three or more) goes to sudden-death decider matches. The
/// schedule comes from the circle method, so appearances spread evenly, and
/// the draw is deterministic from an injected seed, like all randomness here.
public struct League: Equatable, Codable, Sendable {
    /// Every season match in playing order; deciders are not fixtures.
    public private(set) var fixtures: [Pairing]
    /// Season results so far — the standings and head-to-head source.
    public private(set) var played: [MatchResult]
    /// The most recent result, decider matches included.
    public private(set) var lastMatch: MatchResult?
    /// The sudden-death queue once the season ends tied at the top: the front
    /// two play, the loser is out, the winner rejoins the back — nil while the
    /// season runs or when it resolved without deciders.
    public private(set) var contenders: [String]?
    public private(set) var champion: String?

    /// A once-around season of ten is already 45 matches — a whole evening.
    public static let maxPlayers = 10

    /// Draws the schedule. Duplicate names collapse to their first entry — a
    /// name is the only identity there is. Fewer than two distinct names is no
    /// season; past `maxPlayers` no evening is long enough.
    public init?(roster: [String], doubleRound: Bool, seed: UInt64) {
        var seen = Set<String>()
        let players = roster.filter { seen.insert($0).inserted }
        guard players.count >= 2, players.count <= League.maxPlayers else { return nil }
        var rng = SeededRNG(seed: seed)
        let cycle = League.circleFixtures(players.shuffled(using: &rng))
        // The return leg mirrors the ends, so both meetings aren't same-sided.
        fixtures = doubleRound ? cycle + cycle.map(\.mirrored) : cycle
        played = []
    }

    /// Who takes the table now — a fixture, a decider, or nil once decided.
    public var current: Pairing? {
        if champion != nil { return nil }
        if let contenders {
            return Pairing(bottom: contenders[0], top: contenders[1])
        }
        return played.count < fixtures.count ? fixtures[played.count] : nil
    }

    /// One row of the table: matches won and lost so far.
    public struct Standing: Equatable, Sendable {
        public let name: String
        public let wins: Int
        public let losses: Int
    }

    /// The table, best first — by wins, ties in schedule order. The tie order
    /// is load-bearing (it becomes the sudden-death queue), so it sorts on an
    /// explicit schedule index — Swift documents no sort stability to lean on.
    public var standings: [Standing] {
        var order: [String] = []
        for f in fixtures where !order.contains(f.bottom) { order.append(f.bottom) }
        for f in fixtures where !order.contains(f.top) { order.append(f.top) }
        var wins: [String: Int] = [:]
        var losses: [String: Int] = [:]
        for r in played {
            wins[r.winner, default: 0] += 1
            losses[r.loser, default: 0] += 1
        }
        return
            order.enumerated()
            .map {
                (index: $0, row: Standing(name: $1, wins: wins[$1] ?? 0, losses: losses[$1] ?? 0))
            }
            .sorted { $0.row.wins != $1.row.wins ? $0.row.wins > $1.row.wins : $0.index < $1.index }
            .map(\.row)
    }

    /// The current match ended: the given end's player won by the given
    /// tallies (games in a best-of, points in a single game).
    public mutating func recordWin(by side: Side, winnerScore: Int = 0, loserScore: Int = 0) {
        guard let match = current else { return }
        let winner = side == .bottom ? match.bottom : match.top
        let loser = side == .bottom ? match.top : match.bottom
        let result = MatchResult(
            winner: winner, loser: loser, winnerScore: winnerScore, loserScore: loserScore)
        lastMatch = result
        if contenders != nil {
            recordDecider(winner: winner, loser: loser)
            return
        }
        played.append(result)
        if played.count == fixtures.count { resolveSeason() }
    }

    /// A decider fell: the loser is out, the winner rejoins the back of the
    /// queue (so an odd third contender gets the next match), and the last
    /// name in the queue is the champion.
    private mutating func recordDecider(winner: String, loser: String) {
        var queue = contenders ?? []
        queue.removeAll { $0 == loser || $0 == winner }
        queue.append(winner)
        if queue.count == 1 {
            champion = queue[0]
            contenders = nil
        } else {
            contenders = queue
        }
    }

    /// The season is over: a sole leader is the champion; two tied leaders go
    /// to their own head-to-head, and only a split books a decider; three or
    /// more go straight to the sudden-death queue.
    private mutating func resolveSeason() {
        let table = standings
        let tied = table.filter { $0.wins == table[0].wins }.map(\.name)
        if tied.count == 1 {
            champion = tied[0]
        } else if tied.count == 2, let leader = headToHeadLeader(tied[0], tied[1]) {
            champion = leader
        } else {
            contenders = tied
        }
    }

    /// Who won the season meetings between two names — nil when they split.
    private func headToHeadLeader(_ a: String, _ b: String) -> String? {
        let meetings = played.filter {
            ($0.winner == a && $0.loser == b) || ($0.winner == b && $0.loser == a)
        }
        let aWins = meetings.filter { $0.winner == a }.count
        let bWins = meetings.count - aWins
        if aWins == bWins { return nil }
        return aWins > bWins ? a : b
    }

    /// The circle method: one seat fixed, the rest rotate each round, and each
    /// round pairs the ring's ends inward. An odd count adds a ghost seat
    /// whose opponent simply sits the round out — no byes appear anywhere.
    /// Ends alternate by round and pair, so nobody camps one end of the table.
    private static func circleFixtures(_ players: [String]) -> [Pairing] {
        var ring: [String?] = players
        if ring.count % 2 == 1 { ring.append(nil) }
        var fixtures: [Pairing] = []
        for round in 0..<(ring.count - 1) {
            for pair in 0..<(ring.count / 2) {
                guard let a = ring[pair], let b = ring[ring.count - 1 - pair] else { continue }
                fixtures.append(
                    (round + pair) % 2 == 0
                        ? Pairing(bottom: a, top: b) : Pairing(bottom: b, top: a))
            }
            ring.insert(ring.removeLast(), at: 1)
        }
        return fixtures
    }
}
