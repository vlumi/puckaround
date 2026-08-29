/// A side of the oblong — one of the two goals. The two players (or two pairs)
/// defend one each; the puck scores against the side it crosses.
public enum Side: CaseIterable, Codable, Sendable {
    case bottom
    case top

    public var opponent: Side { self == .bottom ? .top : .bottom }

    /// Unit vector from this side's wall toward the middle — its "forward".
    /// World space is y-down, so the bottom side pushes up (−y).
    public var inward: Vec2 {
        self == .bottom ? Vec2(0, -1) : Vec2(0, 1)
    }
}

/// Where in a side's half a mallet lives. Singles fills the whole half; doubles
/// splits it into a left and a right lane so two mallets don't share space.
public enum Lane: Codable, Sendable {
    /// The whole half — a singles mallet.
    case full
    case left
    case right
}

/// One mallet's identity: which side it defends and which lane it keeps. The
/// unit the sim tracks, the touch layer routes to, and the renderer colors.
public struct MalletSlot: Hashable, Codable, Sendable {
    public let side: Side
    public let lane: Lane

    public init(side: Side, lane: Lane) {
        self.side = side
        self.lane = lane
    }
}

/// How many mallets each side fields. Each side is independently one- or
/// two-handed, so the table covers 1v1, 1v2 and 2v2 without a special case:
/// a side's mallet count is all that differs. A side's goal widens with the
/// number of hands defending it, so a lone defender keeps a narrow goal and a
/// pair earns a wider one (see `Playfield.goalWidth(for:)`).
public struct Format: Equatable, Codable, Sendable {
    /// How many mallets a side fields: 1 (a whole-half mallet) or 2 (left+right
    /// lanes). Not an open Int — only these two are meaningful on the oblong.
    public enum Hands: Int, Equatable, Codable, Sendable {
        case one = 1
        case two = 2
    }

    public let bottom: Hands
    public let top: Hands

    public init(bottom: Hands, top: Hands) {
        self.bottom = bottom
        self.top = top
    }

    public static let oneVsOne = Format(bottom: .one, top: .one)
    public static let oneVsTwo = Format(bottom: .one, top: .two)
    public static let twoVsTwo = Format(bottom: .two, top: .two)

    /// How many mallets the given side fields.
    public func hands(on side: Side) -> Hands {
        side == .bottom ? bottom : top
    }

    /// The lanes a side splits into for its hand count: one full lane, or a
    /// left and a right.
    static func lanes(for hands: Hands) -> [Lane] {
        hands == .one ? [.full] : [.left, .right]
    }

    /// Every mallet slot on the table, in a fixed order (bottom's lanes, then
    /// top's), so iteration — and therefore the sim — is deterministic.
    public var slots: [MalletSlot] {
        Side.allCases.flatMap { side in
            Format.lanes(for: hands(on: side)).map { MalletSlot(side: side, lane: $0) }
        }
    }
}
