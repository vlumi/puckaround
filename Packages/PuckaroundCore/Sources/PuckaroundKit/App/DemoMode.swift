import Foundation
import PuckaroundCore

/// **Demo mode — the screenshot stage.** Launching with `-puckaround-demo`
/// routes every store to an ephemeral suite, wiped and re-seeded on each
/// launch with a fixed cast: the remembered-name pool, a bracket tournament
/// one match from the final, and full hiscore boards on all three cabinets.
/// The real player's data is never read and never written, and every demo
/// launch starts from exactly this state, so a capture is reproducible.
public enum DemoMode {
    /// The seeded store when demo mode was requested at launch, else nil.
    /// The app root hands it to `defaultAppStorage`, which re-points every
    /// `@AppStorage` in the tree at once.
    public static func storeIfRequested() -> UserDefaults? {
        guard ProcessInfo.processInfo.arguments.contains("-puckaround-demo"),
            let store = UserDefaults(suiteName: suite)
        else { return nil }
        store.removePersistentDomain(forName: suite)
        seed(store)
        return store
    }

    private static let suite = "fi.misaki.puckaround.demo"

    /// The cast: eight arcade handles, hash-picked so every one auto-assigns
    /// a DIFFERENT neon — boards and brackets light up the whole wardrobe.
    static let cast = ["Glitch", "Synth", "Volt", "Zero", "Echo", "Neon", "Rez", "Pixel"]

    private static func seed(_ store: UserDefaults) {
        let pool = cast.map { NamedPlayer(name: $0, kit: .assigned(to: $0)) }
        store.set(PlayerPool.encode(pool), forKey: "puckaround.playerNames")
        if let evening = try? JSONEncoder().encode(tournament()) {
            store.set(evening, forKey: "puckaround.tournament")
        }
        store.set(board(bumperField), forKey: "puckaround.hiscores.bumperField")
        store.set(board(brickWall), forKey: "puckaround.hiscores.brickWall")
        store.set(board(survival), forKey: "puckaround.hiscores.survival")
    }

    /// A bracket one match from the final: quarterfinals played, one
    /// semifinal in the books — a full first column, bright winners, a live
    /// pairing. The Tournament button resumes it straight at the sheet.
    private static func tournament() -> Evening {
        // Force-unwrap is safe: the cast is a fixed valid roster.
        var evening = Evening.bracket(Bracket(roster: cast, seed: 7)!)
        for (won, lost) in [(7, 4), (7, 2), (7, 5), (7, 6), (7, 3)] {
            guard let pairing = evening.pairing else { break }
            let bottomWins = rank(pairing.bottom) < rank(pairing.top)
            evening.recordWin(
                by: bottomWins ? .bottom : .top, winnerScore: won, loserScore: lost)
        }
        return evening
    }

    /// Earlier in the cast plays better — a fixed pecking order keeps the
    /// seeded results deterministic whatever the draw dealt.
    private static func rank(_ name: String) -> Int {
        cast.firstIndex(of: name) ?? .max
    }

    /// One seeded board line: who (a cast index), the score, and — on staged
    /// cabinets — the stage the run died on.
    private struct Line {
        let cast: Int
        let score: Int
        var stage: Int?

        init(_ cast: Int, _ score: Int, _ stage: Int? = nil) {
            self.cast = cast
            self.score = score
            self.stage = stage
        }
    }

    /// Submitted lowest first, so every row qualifies and the ordering is the
    /// board's own.
    private static func board(_ rows: [Line]) -> Data {
        var board = Hiscores()
        for row in rows.sorted(by: { $0.score < $1.score }) {
            _ = board.submit(name: cast[row.cast], score: row.score, stage: row.stage)
        }
        return (try? JSONEncoder().encode(board)) ?? Data()
    }

    private static let bumperField: [Line] = [
        Line(2, 14200, 8), Line(0, 11350, 7), Line(7, 9800, 6), Line(4, 8100, 5),
        Line(1, 7450, 5), Line(5, 6300, 4), Line(3, 5150, 3), Line(6, 3900, 3),
        Line(2, 2600, 2), Line(0, 1400, 1),
    ]

    private static let brickWall: [Line] = [
        Line(0, 21700, 11), Line(7, 17250, 9), Line(2, 14800, 8), Line(5, 12500, 7),
        Line(3, 9700, 6), Line(4, 7900, 5), Line(1, 5600, 4), Line(6, 4200, 3),
        Line(0, 2900, 2), Line(7, 1500, 1),
    ]

    private static let survival: [Line] = [
        Line(7, 6240), Line(4, 5180), Line(0, 4470), Line(5, 3820), Line(2, 3150),
        Line(6, 2610), Line(1, 2040), Line(3, 1580), Line(4, 1120), Line(7, 680),
    ]
}
