/// **The board.** The top runs of one arcade minigame — rank, name, score,
/// nothing else, like a real cabinet's. Names come from the same remembered
/// pool as tournaments (full names, not three-letter truncations), and the
/// board is device-local: graffiti, not profiles.
public struct Hiscores: Equatable, Codable, Sendable {
    public struct Entry: Equatable, Codable, Sendable {
        public let name: String
        public let score: Int

        public init(name: String, score: Int) {
            self.name = name
            self.score = score
        }
    }

    /// Best first. Never longer than `capacity`.
    public private(set) var entries: [Entry] = []

    /// A real cabinet's ten lines.
    public static let capacity = 10

    public init() {}

    /// Whether a run makes the board: it beats the last line, or the board
    /// still has room. A scoreless run never boards.
    public func qualifies(_ score: Int) -> Bool {
        guard score > 0 else { return false }
        return entries.count < Hiscores.capacity || score > entries[entries.count - 1].score
    }

    /// Sign a qualifying run onto the board; returns the 1-based rank it took,
    /// or nil if it didn't board. A tie slots below the earlier holder — being
    /// there first is worth something on a cabinet.
    public mutating func submit(name: String, score: Int) -> Int? {
        guard qualifies(score) else { return nil }
        let index = entries.firstIndex { $0.score < score } ?? entries.count
        entries.insert(Entry(name: name, score: score), at: index)
        if entries.count > Hiscores.capacity { entries.removeLast() }
        return index + 1
    }
}
