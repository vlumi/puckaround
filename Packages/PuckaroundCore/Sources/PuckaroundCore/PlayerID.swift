/// A seat at the table, 0-based. Stable for the whole match: inputs, teams and
/// colors are all keyed by it.
public struct PlayerID: Hashable, Comparable, Codable, Sendable {
    public let rawValue: Int

    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    public static func < (a: PlayerID, b: PlayerID) -> Bool { a.rawValue < b.rawValue }
}

/// Sim ticks since the match started (fixed timestep — see `Rink`).
public typealias Tick = Int
