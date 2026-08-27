import PuckaroundCore
import SwiftUI

/// Everything one frame needs, as plain values (the Canvas renderer closure is
/// not MainActor, so it gets copies, not the session).
struct RinkScene {
    var rink: Rink
    /// Where the table is placed on screen — the one primitive the renderer and
    /// the touch mapping both key off.
    var tableRect: CGRect
}

enum RinkRenderer {
    static let ground = Color(red: 0.09, green: 0.10, blue: 0.14)
    static let ice = Color(red: 0.93, green: 0.94, blue: 0.96)
    static let lines = Color(red: 0.55, green: 0.62, blue: 0.75)
    static let puck = Color(red: 0.08, green: 0.08, blue: 0.10)

    /// The table letterboxed into the screen: as big as its aspect allows
    /// inside `margin`, centred.
    static func fittedTableRect(tableSize: Vec2, in screen: CGSize, margin: CGFloat = 12) -> CGRect
    {
        let box = CGRect(origin: .zero, size: screen).insetBy(dx: margin, dy: margin)
        guard box.width > 0, box.height > 0 else { return .zero }
        let scale = min(box.width / tableSize.x, box.height / tableSize.y)
        let fitted = CGSize(width: tableSize.x * scale, height: tableSize.y * scale)
        return CGRect(
            x: box.minX + (box.width - fitted.width) / 2,
            y: box.minY + (box.height - fitted.height) / 2,
            width: fitted.width, height: fitted.height)
    }

    /// Screen-space helpers for one frame: world → screen is a translate + scale.
    private struct Projection {
        let table: Playfield
        let rect: CGRect
        let scale: CGFloat

        func point(_ p: Vec2) -> CGPoint {
            CGPoint(x: rect.minX + p.x * scale, y: rect.minY + p.y * scale)
        }

        func rect(_ r: Rect) -> CGRect {
            CGRect(
                origin: point(r.origin),
                size: CGSize(width: r.width * scale, height: r.height * scale))
        }

        func disc(at center: CGPoint, radius: CGFloat) -> Path {
            Path(
                ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius, width: 2 * radius,
                    height: 2 * radius))
        }
    }

    static func draw(_ scene: RinkScene, in context: inout GraphicsContext, size: CGSize) {
        let table = scene.rink.table
        let rect = scene.tableRect
        guard rect.width > 0 else { return }
        let projection = Projection(table: table, rect: rect, scale: rect.width / table.size.x)
        let lineup = scene.rink.lineup

        context.fill(Path(roundedRect: rect, cornerRadius: 6 * projection.scale), with: .color(ice))
        drawMarkings(projection: projection, in: &context)
        for player in lineup.players {
            let edge = lineup.seat(of: player)
            let color = SeatPalette.color(for: player, in: lineup)
            drawScore(
                scene.rink.score(of: player), at: edge, color: color,
                projection: projection, in: &context)
            drawGoal(at: edge, projection: projection, in: &context)
            if case .finished(let winner) = scene.rink.phase {
                drawVerdict(
                    won: winner == player, in: projection.rect(table.malletZone(for: edge)),
                    facing: edge, color: color, in: &context)
            }
            drawMallet(
                scene.rink.mallet(of: player), radius: table.malletRadius, color: color,
                projection: projection, in: &context)
        }
        drawPuck(scene.rink.puck, radius: table.puckRadius, projection: projection, in: &context)
    }

    /// Centre ring and centre line.
    private static func drawMarkings(projection: Projection, in context: inout GraphicsContext) {
        let table = projection.table
        let centre = projection.point(table.center)
        let lineWidth = max(1, 0.6 * projection.scale)
        context.stroke(
            projection.disc(at: centre, radius: 10 * projection.scale), with: .color(lines),
            lineWidth: lineWidth)
        var midline = Path()
        midline.move(to: CGPoint(x: projection.rect.minX, y: centre.y))
        midline.addLine(to: CGPoint(x: projection.rect.maxX, y: centre.y))
        context.stroke(midline, with: .color(lines), lineWidth: lineWidth)
    }

    /// The goal mouth: a slot in the short wall, in the ground colour, so the
    /// puck visibly leaves the ice through it.
    private static func drawGoal(
        at edge: Seat, projection: Projection, in context: inout GraphicsContext
    ) {
        let table = projection.table
        let width = table.goalWidth * projection.scale
        let depth = 3 * projection.scale
        let x = projection.rect.midX - width / 2
        let y: CGFloat
        switch edge {
        case .top: y = projection.rect.minY - depth
        case .bottom: y = projection.rect.maxY - depth
        case .left, .right: return
        }
        context.fill(
            Path(
                roundedRect: CGRect(x: x, y: y, width: width, height: 2 * depth),
                cornerRadius: depth / 2),
            with: .color(ground))
    }

    /// The seat's score, in the corner beside its goal mouth — on the player's
    /// LEFT, so it mirrors for the top seat — turned to face them. Out of the
    /// middle of the half, where the mallet lives and was covering it.
    private static func drawScore(
        _ score: Int, at edge: Seat, color: Color, projection: Projection,
        in context: inout GraphicsContext
    ) {
        let table = projection.table
        // The middle of the strip between the side wall and the goal post.
        let beside = (table.size.x - table.goalWidth) / 4
        let inset = table.malletRadius * 1.6
        let spot =
            edge == .top ? Vec2(table.size.x - beside, inset) : Vec2(beside, table.size.y - inset)
        var ctx = context
        let at = projection.point(spot)
        ctx.translateBy(x: at.x, y: at.y)
        if edge == .top {
            ctx.rotate(by: .degrees(180))
        }
        var text = ctx.resolve(
            Text(verbatim: "\(score)").font(
                .system(size: 14 * projection.scale, weight: .black, design: .rounded)))
        text.shading = .color(color.opacity(0.5))
        ctx.draw(text, at: .zero, anchor: .center)
    }

    /// WIN or LOSE, on the seat's side of the centre line, turned to face its
    /// player — so both verdicts read at once from opposite ends of the table.
    private static func drawVerdict(
        won: Bool, in half: CGRect, facing edge: Seat, color: Color,
        in context: inout GraphicsContext
    ) {
        var ctx = context
        let towardCentre = half.height * 0.22
        let y = edge == .top ? half.maxY - towardCentre : half.minY + towardCentre
        ctx.translateBy(x: half.midX, y: y)
        if edge == .top {
            ctx.rotate(by: .degrees(180))
        }
        let word = won ? Text("WIN", bundle: .module) : Text("LOSE", bundle: .module)
        var text = ctx.resolve(
            word.font(.system(size: half.height * 0.16, weight: .black, design: .rounded)))
        text.shading = .color(color.opacity(won ? 0.9 : 0.45))
        ctx.draw(text, at: .zero, anchor: .center)
    }

    private static func drawMallet(
        _ mallet: Mallet, radius: Double, color: Color, projection: Projection,
        in context: inout GraphicsContext
    ) {
        let p = projection.point(mallet.position)
        let r = radius * projection.scale
        context.fill(projection.disc(at: p, radius: r), with: .color(color))
        context.stroke(
            projection.disc(at: p, radius: r), with: .color(puck.opacity(0.5)),
            lineWidth: max(1, 0.5 * projection.scale))
        context.fill(projection.disc(at: p, radius: r * 0.45), with: .color(puck.opacity(0.25)))
    }

    /// A dark disc with a small highlight so its motion reads.
    private static func drawPuck(
        _ puck: Puck, radius: Double, projection: Projection, in context: inout GraphicsContext
    ) {
        let p = projection.point(puck.position)
        let r = radius * projection.scale
        context.fill(projection.disc(at: p, radius: r), with: .color(RinkRenderer.puck))
        let highlight = CGPoint(x: p.x - r * 0.45, y: p.y - r * 0.45)
        context.fill(
            projection.disc(at: highlight, radius: r * 0.175),
            with: .color(Color.white.opacity(0.25)))
    }
}
