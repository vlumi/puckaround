import PuckaroundCore
import SwiftUI

/// **How the portrait board sits on the screen.** In portrait it's centered and
/// scaled to fit. In landscape the whole board turns a quarter and fills the
/// wide screen — so the players sit along the long (bottom) edge and see an
/// upright table, no wasted side bars. One source of truth for both the renderer
/// (which rotates the canvas) and the touch mapping (which must invert the same
/// rotation), so a finger lands where it looks.
struct BoardPlacement {
    /// The board size in world units (portrait: width < height).
    let board: Vec2
    /// The screen (canvas) size in points.
    let screen: CGSize
    /// Quarter-turn applied to the board, so a landscape screen shows it upright
    /// to a bench player. Zero in portrait.
    let turn: Angle
    /// World units → points.
    let scale: CGFloat
    /// The board's center on screen, the pivot of `turn`.
    let center: CGPoint

    var landscape: Bool { screen.width > screen.height }

    /// `turnCW` is +90 for one landscape and −90 for the other, so the board
    /// turns the same way the phone did — magenta stays on the physical-bottom
    /// edge whichever way you rotate. Ignored in portrait.
    init(board: Vec2, screen: CGSize, turnCW: Bool = true, margin: CGFloat = 12) {
        self.board = board
        self.screen = screen
        let landscape = screen.width > screen.height
        // The box the board must fit inside its own (possibly turned) frame: in
        // landscape the board's width spans the screen height and vice versa.
        let boxW = max(0, (landscape ? screen.height : screen.width) - 2 * margin)
        let boxH = max(0, (landscape ? screen.width : screen.height) - 2 * margin)
        scale = board.x > 0 ? min(boxW / board.x, boxH / board.y) : 0
        center = CGPoint(x: screen.width / 2, y: screen.height / 2)
        turn = landscape ? .degrees(turnCW ? 90 : -90) : .degrees(0)
    }

    /// The affine transform world → screen: scale, rotate about the board center,
    /// translate to the screen center. Points are `board`-space (origin top-left,
    /// y-down); the board's own center is `board/2`.
    private var toScreen: CGAffineTransform {
        CGAffineTransform.identity
            .translatedBy(x: center.x, y: center.y)
            .rotated(by: turn.radians)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -board.x / 2, y: -board.y / 2)
    }

    func point(_ world: Vec2) -> CGPoint {
        CGPoint(x: world.x, y: world.y).applying(toScreen)
    }

    /// Screen point → world, inverting the same transform, so touches match what
    /// is drawn under them.
    func world(fromScreen p: CGPoint) -> Vec2 {
        let t = toScreen.inverted()
        let q = p.applying(t)
        return Vec2(q.x, q.y)
    }

    /// A board-space length (e.g. a radius) in points.
    func length(_ world: Double) -> CGFloat { world * scale }
}
