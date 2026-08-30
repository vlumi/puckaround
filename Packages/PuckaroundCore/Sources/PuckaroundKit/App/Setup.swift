import PuckaroundCore
import SwiftUI

/// **The setup choices as a plain value** — every pick the front door and the
/// in-game sheet offer. Held whole so it can be snapshotted (the sheet's draft,
/// compared to decide whether a change restarts the game) and stored field by
/// field in `@AppStorage`.
///
/// `randomPuck` / `randomWalls` are the "?" picks: when on, the concrete shape
/// or wall stored beside them is ignored and rolled fresh each game (see
/// `resolvedPuck` / `resolvedWalls`), so the pill can remember a real choice to
/// fall back to when "?" is turned off again.
struct Setup: Equatable {
    var pointsToWin = 7
    var gamesToWin = 1
    var puckShapeKey = PuckShapeKey.circle.rawValue
    var randomPuck = false
    var bottomHands = 1
    var topHands = 1
    var wrapWalls = false
    var randomWalls = false
}

extension Setup {
    var rules: Rules { Rules(pointsToWin: pointsToWin, gamesToWin: gamesToWin) }

    /// The stored per-side hand counts as a `Format` (anything but 1 or 2 falls
    /// back to one hand, so a stale or bad stored value can't crash the table).
    var format: Format {
        Format(bottom: bottomHands == 2 ? .two : .one, top: topHands == 2 ? .two : .one)
    }

    /// The puck to play with — the picked shape, or a random one when "?" is on.
    /// `roll` is drawn once per game so the shape holds for that whole game.
    func resolvedPuck(roll: UInt64) -> PuckShape {
        let key =
            randomPuck
            ? PuckShapeKey.allCases[Int(roll % UInt64(PuckShapeKey.allCases.count))]
            : PuckShapeKey(rawValue: puckShapeKey) ?? .circle
        return key.shape
    }

    /// Solid or wrap walls — the picked one, or a coin-flip when "?" is on.
    func resolvedWalls(roll: UInt64) -> SideWalls {
        let wrap = randomWalls ? (roll & 1) == 1 : wrapWalls
        return wrap ? .wrap : .solid
    }
}
