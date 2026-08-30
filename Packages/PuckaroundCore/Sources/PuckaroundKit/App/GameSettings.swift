import PuckaroundCore
import SwiftUI

/// **The bag of setup choices**, bound straight to `@AppStorage`, so the front
/// door and the in-game settings sheet edit one source of truth. Held as a
/// value of `Binding`s rather than passing six of them everywhere.
///
/// `randomPuck` / `randomWalls` are the "?" picks: when on, the concrete shape
/// or wall stored beside them is ignored and rolled fresh each game (see
/// `resolvedPuck` / `resolvedWalls`), so the pill can remember a real choice to
/// fall back to when "?" is turned off again.
struct GameSettings {
    @Binding var pointsToWin: Int
    @Binding var gamesToWin: Int
    @Binding var puckShapeKey: String
    @Binding var randomPuck: Bool
    @Binding var bottomHands: Int
    @Binding var topHands: Int
    @Binding var wrapWalls: Bool
    @Binding var randomWalls: Bool
}

extension GameSettings {
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
