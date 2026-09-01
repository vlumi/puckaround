import PuckaroundCore
import SwiftUI

// MARK: - The cabinet: bumpers & the arcade HUD

extension RinkRenderer {
    /// Bumpers: neutral glowing rings with a dot of a hub — table furniture
    /// owned by nobody, so they read as part of the rink like the boards do.
    /// Drawn on any table that seats them, couch variants included.
    static func drawBumpers(
        _ scene: RinkScene, projection: Projection, in context: inout GraphicsContext
    ) {
        for bumper in scene.rink.table.bumpers {
            let p = projection.point(bumper.position)
            let r = bumper.radius * projection.scale
            let ring = projection.disc(at: p, radius: r)
            context.fill(ring, with: .color(line.opacity(0.08)))
            glowStroke(
                ring, color: line.opacity(0.8), lineWidth: max(1.5, 1.2 * projection.scale),
                blur: 5 * projection.scale, in: &context)
            context.fill(
                projection.disc(at: p, radius: r * 0.25), with: .color(line.opacity(0.5)))
        }
    }

    /// The wall still standing: each brick a faint block with a glowing edge —
    /// neutral furniture that reads as "boards you can break", not a seat's.
    static func drawBricks(
        _ scene: RinkScene, projection: Projection, in context: inout GraphicsContext
    ) {
        for brick in scene.rink.bricks {
            let inset = 0.6 * projection.scale
            let rect = projection.rect(brick.rect).insetBy(dx: inset, dy: inset)
            let block = Path(roundedRect: rect, cornerRadius: 1.5 * projection.scale)
            context.fill(block, with: .color(line.opacity(0.12)))
            glowStroke(
                block, color: line.opacity(0.55), lineWidth: max(1, 0.7 * projection.scale),
                blur: 3 * projection.scale, in: &context)
        }
    }

    /// The arcade HUD: the run's score across the machine's empty end and a
    /// row of life pucks under it, facing the player like everything theirs.
    /// Neutral ink — the score is the table's, not a side's.
    static func drawArcadeHUD(
        _ scene: RinkScene, projection: Projection, in context: inout GraphicsContext
    ) {
        guard let run = scene.arcade else { return }
        let table = scene.rink.table
        let seat = Seat(side: .bottom, boardTurn: scene.placement.turn)
        var ctx = context
        let at = projection.point(Vec2(table.center.x, 10))
        ctx.translateBy(x: at.x, y: at.y)
        ctx.rotate(by: seat.labelAngle)
        let text = ctx.resolve(
            Text(verbatim: "\(run.score)")
                .font(
                    .system(size: 10 * projection.scale, weight: .black, design: .rounded)
                        .monospacedDigit()))
        var haze = ctx
        haze.addFilter(.blur(radius: 3 * projection.scale))
        haze.draw(colored(text, line.opacity(0.9)), at: .zero, anchor: .center)
        ctx.draw(colored(text, line), at: .zero, anchor: .center)
        // One small puck per life left, in a row under the score.
        let r = 2.0 * projection.scale
        let gap = 7.0 * projection.scale
        let span = CGFloat(max(0, run.lives - 1)) * gap
        for life in 0..<max(0, run.lives) {
            let dot = CGPoint(x: -span / 2 + CGFloat(life) * gap, y: 8.5 * projection.scale)
            ctx.fill(
                Path(
                    ellipseIn: CGRect(x: dot.x - r, y: dot.y - r, width: 2 * r, height: 2 * r)),
                with: .color(puck))
        }
    }
}
