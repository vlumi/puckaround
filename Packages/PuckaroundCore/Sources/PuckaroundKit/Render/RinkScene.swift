import PuckaroundCore
import SwiftUI

/// Everything one frame needs, as plain values (the Canvas renderer closure is
/// not MainActor, so it gets copies, not the session).
struct RinkScene {
    var rink: Rink
    /// Where the table is placed on screen — the one primitive the renderer and
    /// the touch mapping both key off.
    var tableRect: CGRect
    /// Decorative motion (the scanline breath, a longer puck trail) is off when
    /// the viewer asks for reduced motion. The game itself still moves.
    var reducedMotion = false
    /// A rising time base for ambient effects; the view feeds it the frame time.
    var time: Double = 0
    /// 0→1 progress of the faceoff-clears burst, or nil when not bursting.
    var faceoffBurst: Double?

    /// How long the burst ring animates, in seconds.
    static let burstDuration = 0.45
}
