import PuckaroundCore
import SwiftUI

/// Everything one frame needs, as plain values (the Canvas renderer closure is
/// not MainActor, so it gets copies, not the session).
struct RinkScene {
    var rink: Rink
    /// How the board sits on screen — fit, rotation and coordinate mapping. The
    /// renderer and the touch mapping both key off it.
    var placement: BoardPlacement
    /// Decorative motion (the scanline breath, a longer puck trail) is off when
    /// the viewer asks for reduced motion. The game itself still moves.
    var reducedMotion = false
    /// A rising time base for ambient effects; the view feeds it the frame time.
    var time: Double = 0
    /// 0→1 progress of the faceoff-clears burst, or nil when not bursting.
    var faceoffBurst: Double?

    /// The named ends during a tournament, or nil in a plain match.
    var names: EndNames?
    /// The ends' kit colors during a tournament, or nil for the classic pair.
    var colors: EndColors?

    /// What a side's furniture (mallet, goal, score, verdicts) wears: the
    /// player's kit when the ends are named, the classic pair otherwise.
    func sideColor(for side: Side) -> Color {
        colors?.color(for: side) ?? SeatPalette.color(for: side)
    }

    /// How long the burst ring animates, in seconds.
    static let burstDuration = 0.45
}

/// Who defends which end, by name — tournament labels for the renderer. Kit-only:
/// the sim never sees a name (identity ends at the table, see `MalletSlot`).
struct EndNames {
    var bottom: String
    var top: String

    func name(for side: Side) -> String { side == .bottom ? bottom : top }
}

/// The kit colors on the two ends — already clash-resolved (see
/// `PlayerKit.resolve`), so the pair is always distinct. Kit-only, like names.
struct EndColors {
    var bottom: Color
    var top: Color

    func color(for side: Side) -> Color { side == .bottom ? bottom : top }
}
