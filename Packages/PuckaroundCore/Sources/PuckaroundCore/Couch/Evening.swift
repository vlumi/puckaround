/// **One evening of tournament play, whichever shape it takes.** The flow
/// drives this single handle: who plays now, record the result, what the
/// banner says, whether a champion stands. Each shape keeps its own richer
/// state underneath (the line and streaks, or the sheet).
public enum Evening: Equatable, Codable, Sendable {
    case winnerStays(Tournament)
    case bracket(Bracket)
    case league(League)

    /// The shapes on offer, for the roster sheet's picker.
    public enum Shape: String, CaseIterable, Codable, Sendable {
        case winnerStays
        case bracket
        case league
    }

    public var shape: Shape {
        switch self {
        case .winnerStays: return .winnerStays
        case .bracket: return .bracket
        case .league: return .league
        }
    }

    /// Who takes the table now — nil once a knockout or season is decided.
    public var pairing: Pairing? {
        switch self {
        case .winnerStays(let t): return Pairing(bottom: t.bottom, top: t.top)
        case .bracket(let b): return b.current
        case .league(let l): return l.current
        }
    }

    /// The most recent result, for the between-matches banner.
    public var lastMatch: MatchResult? {
        switch self {
        case .winnerStays(let t): return t.lastMatch
        case .bracket(let b): return b.lastMatch
        case .league(let l): return l.lastMatch
        }
    }

    /// The last name standing — a winner-stays evening never produces one.
    public var champion: String? {
        switch self {
        case .winnerStays: return nil
        case .bracket(let b): return b.champion
        case .league(let l): return l.champion
        }
    }

    public mutating func recordWin(by side: Side, winnerScore: Int, loserScore: Int) {
        switch self {
        case .winnerStays(var t):
            t.recordWin(by: side, winnerScore: winnerScore, loserScore: loserScore)
            self = .winnerStays(t)
        case .bracket(var b):
            b.recordWin(by: side, winnerScore: winnerScore, loserScore: loserScore)
            self = .bracket(b)
        case .league(var l):
            l.recordWin(by: side, winnerScore: winnerScore, loserScore: loserScore)
            self = .league(l)
        }
    }
}
