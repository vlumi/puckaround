/// **The cabinet's score-attack loop.** Turns one game's event stream into an
/// arcade run: bumpers and bricks pay, a goal into the far end pays big, and
/// a failed stage — every puck drained with nothing scored — costs a life;
/// the run ends at zero. The sim itself never ends an arcade game (its points
/// target is set out of reach); this is what does. The player always defends
/// the bottom end.
public struct ScoreAttack: Equatable, Sendable {
    public private(set) var score = 0
    public private(set) var lives: Int
    /// Survival runs: living pays by the tick, and every drain costs a life
    /// directly — there are no stages to fail.
    public let survival: Bool
    /// Sim ticks lived so far (survival runs only).
    public private(set) var ticks = 0

    public static let bumperPoints = 100
    public static let brickPoints = 100
    public static let goalPoints = 1000

    public init(lives: Int = 3, survival: Bool = false) {
        self.lives = lives
        self.survival = survival
    }

    public var isOver: Bool { lives <= 0 }

    /// One sim tick lived: every sixth pays a point — ten a second at 60 Hz.
    public mutating func survive() {
        guard survival, !isOver else { return }
        ticks += 1
        if ticks.isMultiple(of: 6) { score += 1 }
    }

    /// Feed one tick's events. A finished run ignores everything after.
    public mutating func ingest(_ events: [GameEvent]) {
        guard !isOver else { return }
        for event in events {
            switch event {
            case .bumperHit:
                score += ScoreAttack.bumperPoints
            case .brickBroken, .brickChipped:
                score += ScoreAttack.brickPoints
            case .goal(_, let conceder):
                if conceder != .bottom {
                    score += ScoreAttack.goalPoints
                } else if survival {
                    lives -= 1
                }
            case .stageFailed:
                lives -= 1
            default:
                break
            }
        }
    }
}
