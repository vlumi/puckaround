import PuckaroundCore
import SwiftUI

/// **Neon cabinet.** A dark playfield that glows: a neutral rink (ice, grid,
/// center line, puck) that belongs to no seat, and the two players' colors on
/// exactly the three things that are theirs — mallet, goal, score. Glow is
/// additive over a solid core, so a hard puck and a readable score survive the
/// bloom. All procedural; no assets. Being a committed dark look, it has no
/// light variant.
enum RinkRenderer {
    /// The cabinet the table sits in — a near-black with a faint violet bias.
    static let ground = Color(red: 0.039, green: 0.024, blue: 0.071)
    /// The ice: a dark neutral playfield, not white — the glow does the lifting.
    static let ice = Color(red: 0.071, green: 0.043, blue: 0.122)
    /// Rink furniture: grid, center line, ring. A cool neutral owned by nobody.
    static let line = Color(red: 0.60, green: 0.72, blue: 0.95)
    /// The puck: white-hot, so it reads against every seat color and the ice.
    static let puck = Color(red: 0.97, green: 0.96, blue: 1.0)

    /// The center ring's radius in world units — the menu button. Shared so the
    /// touch target (in the view) matches the drawn ring exactly.
    static let centerRingRadius: Double = 16

    /// The table letterboxed into the screen: as big as its aspect allows
    /// inside `margin`, centerd.
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
    struct Projection {
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

    /// A glowing fill: the shape drawn once blurred (the bloom) and once solid
    /// (the core), so the color stays legible while still emitting.
    static func glow(
        _ path: Path, color: Color, blur: CGFloat, core: Double = 1,
        in context: inout GraphicsContext
    ) {
        var haze = context
        haze.addFilter(.blur(radius: blur))
        haze.fill(path, with: .color(color.opacity(0.9)))
        context.fill(path, with: .color(color.opacity(core)))
    }

    static func glowStroke(
        _ path: Path, color: Color, lineWidth: CGFloat, blur: CGFloat,
        in context: inout GraphicsContext
    ) {
        var haze = context
        haze.addFilter(.blur(radius: blur))
        haze.stroke(path, with: .color(color.opacity(0.85)), lineWidth: lineWidth)
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    static func draw(_ scene: RinkScene, in context: inout GraphicsContext, size: CGSize) {
        let table = scene.rink.table
        let rect = scene.tableRect
        guard rect.width > 0 else { return }
        let projection = Projection(table: table, rect: rect, scale: rect.width / table.size.x)

        drawRink(
            projection: projection, time: scene.time, reducedMotion: scene.reducedMotion,
            in: &context)
        drawLaneDividers(scene, projection: projection, in: &context)
        drawSides(scene, projection: projection, in: &context)
        // The menu glyph is always there — the center ring is always the menu.
        // It sits UNDER the puck (drawn next), so during a faceoff the frozen
        // puck rests on it; that's fine, it's furniture, and an empty ring would
        // read as broken.
        drawMenuGlyph(projection: projection, in: &context)
        if scene.rink.isFaceoff {
            drawFaceoffBubble(
                around: scene.rink.puck.position, radius: table.faceoffBubbleRadius,
                ripple: Ripple(active: true, time: scene.time, reducedMotion: scene.reducedMotion),
                projection: projection, in: &context)
        }
        drawPuck(
            scene.rink.puck, radius: table.puckRadius, shape: table.puckShape,
            projection: projection, in: &context)
        // Mallets last — above the puck and the center glyph, since they're hands.
        drawMallets(scene, projection: projection, in: &context)
        if let burst = scene.faceoffBurst, !scene.reducedMotion {
            drawFaceoffBurst(
                at: projection.point(table.center),
                from: table.faceoffBubbleRadius * projection.scale,
                progress: burst, in: &context)
        }
        if !scene.reducedMotion {
            drawScanline(rect: rect, time: scene.time, in: &context)
        }
    }

    /// Each side's colored furniture: goal, score, verdict, ready prompt. The
    /// mallets are drawn later (see `drawMallets`), on top of everything.
    private static func drawSides(
        _ scene: RinkScene, projection: Projection, in context: inout GraphicsContext
    ) {
        let table = scene.rink.table
        let halfHeight = table.size.y / 2
        for side in Side.allCases {
            let color = SeatPalette.color(for: side)
            // A side's own half, full width (both doubles lanes), split at the
            // center line — the surface its verdict and ready prompt sit on.
            let half = projection.rect(
                Rect(
                    x: 0, y: side == .bottom ? halfHeight : 0, width: table.size.x,
                    height: halfHeight))
            let score = scene.rink.score(of: side)
            drawScore(score, at: side, color: color, projection: projection, in: &context)
            drawGoal(at: side, color: color, projection: projection, in: &context)
            // The result stays up through the rematch faceoff, so players see
            // who won while deciding to go again.
            if let winner = scene.rink.finalWinner {
                drawVerdict(
                    won: winner == side, in: half, facing: side, color: color, in: &context)
            }
            if scene.rink.isFaceoff {
                drawSideReadiness(
                    scene, side: side, half: half, color: color, in: &context)
            }
        }
    }

    /// The ice, a faint neutral grid clipped to it, and a glowing border +
    /// center line — all neutral, so the rink belongs to no player.
    private static func drawRink(
        projection: Projection, time: Double, reducedMotion: Bool,
        in context: inout GraphicsContext
    ) {
        let rect = projection.rect
        let corner = 8 * projection.scale
        let iceShape = Path(roundedRect: rect, cornerRadius: corner)
        context.fill(iceShape, with: .color(ice))

        context.drawLayer { layer in
            layer.clip(to: iceShape)
            let step = 8 * projection.scale
            var grid = Path()
            var x = rect.minX
            while x <= rect.maxX {
                grid.move(to: CGPoint(x: x, y: rect.minY))
                grid.addLine(to: CGPoint(x: x, y: rect.maxY))
                x += step
            }
            var y = rect.minY
            while y <= rect.maxY {
                grid.move(to: CGPoint(x: rect.minX, y: y))
                grid.addLine(to: CGPoint(x: rect.maxX, y: y))
                y += step
            }
            layer.stroke(grid, with: .color(line.opacity(0.10)), lineWidth: 1)
        }

        if projection.table.sideWalls == .wrap {
            drawWrapBorder(
                time: time, reducedMotion: reducedMotion, projection: projection, in: &context)
        } else {
            glowStroke(
                iceShape, color: line.opacity(0.9), lineWidth: max(1.5, 1.4 * projection.scale),
                blur: 4 * projection.scale, in: &context)
        }

        // The center line is INTERRUPTED by the center circle — as on a real
        // rink — so it runs edge → ring on each side and leaves the ring's
        // interior clean for the puck and the menu glyph.
        let center = projection.point(projection.table.center)
        let ringRadius = centerRingRadius * projection.scale
        var midline = Path()
        midline.move(to: CGPoint(x: rect.minX, y: center.y))
        midline.addLine(to: CGPoint(x: center.x - ringRadius, y: center.y))
        midline.move(to: CGPoint(x: center.x + ringRadius, y: center.y))
        midline.addLine(to: CGPoint(x: rect.maxX, y: center.y))
        let ring = projection.disc(at: center, radius: ringRadius)
        glowStroke(
            midline, color: line.opacity(0.55), lineWidth: max(1, 0.8 * projection.scale),
            blur: 3 * projection.scale, in: &context)
        glowStroke(
            ring, color: line.opacity(0.55), lineWidth: max(1, 0.8 * projection.scale),
            blur: 3 * projection.scale, in: &context)
    }

    /// A hamburger inside the center ring — the menu affordance, so the center
    /// tap target is discoverable. Three short bars, neutral (they read the same
    /// from both ends). Always drawn (the ring is always the menu); it sits
    /// under the puck, which rests on it during a faceoff.
    private static func drawMenuGlyph(projection: Projection, in context: inout GraphicsContext) {
        let center = projection.point(projection.table.center)
        let barWidth = 15 * projection.scale
        let barGap = 5.5 * projection.scale
        var bars = Path()
        for row in -1...1 {
            let y = center.y + CGFloat(row) * barGap
            bars.move(to: CGPoint(x: center.x - barWidth / 2, y: y))
            bars.addLine(to: CGPoint(x: center.x + barWidth / 2, y: y))
        }
        context.stroke(
            bars, with: .color(line.opacity(0.6)),
            style: StrokeStyle(lineWidth: max(2, 2 * projection.scale), lineCap: .round))
    }

    /// The goal mouth: a glowing bar in the side's own color, set into its
    /// short wall — one of the three things that color owns. Its width is that
    /// side's own (wider when two defenders share it).
    private static func drawGoal(
        at side: Side, color: Color, projection: Projection, in context: inout GraphicsContext
    ) {
        let table = projection.table
        // Draw the SCORING mouth (posts inset by a puck radius), not the raw
        // opening, so a puck that reaches the drawn goal actually counts.
        let width = table.goalMouthWidth(for: side) * projection.scale
        let x = projection.rect.midX - width / 2
        let y = side == .top ? projection.rect.minY : projection.rect.maxY
        var bar = Path()
        bar.move(to: CGPoint(x: x, y: y))
        bar.addLine(to: CGPoint(x: x + width, y: y))
        glowStroke(
            bar, color: color, lineWidth: max(3, 2.4 * projection.scale),
            blur: 5 * projection.scale, in: &context)
    }

    /// The side's score, in the corner beside its goal, turned to face its
    /// player — a bright core over a glow, so a glanced number stays legible.
    private static func drawScore(
        _ score: Int, at side: Side, color: Color, projection: Projection,
        in context: inout GraphicsContext
    ) {
        let table = projection.table
        // The number is ~15 world units tall, so its center must sit clear of
        // both the short wall (above/below) and the side wall (a wide doubles
        // goal narrows the strip beside the post, pulling it toward the side).
        let halfGlyph = 8.0
        // The middle of the strip between the side wall and the goal post, but
        // never closer to the side wall than the glyph's own half-width.
        let strip = (table.size.x - table.goalWidth(for: side)) / 4
        let beside = max(strip, halfGlyph + 2)
        let inset = halfGlyph + 4
        let spot =
            side == .top ? Vec2(table.size.x - beside, inset) : Vec2(beside, table.size.y - inset)
        var ctx = context
        let at = projection.point(spot)
        ctx.translateBy(x: at.x, y: at.y)
        if side == .top {
            ctx.rotate(by: .degrees(180))
        }
        let text = ctx.resolve(
            Text(verbatim: "\(score)").font(
                .system(size: 15 * projection.scale, weight: .black, design: .rounded)))
        var haze = ctx
        haze.addFilter(.blur(radius: 4 * projection.scale))
        haze.draw(colored(text, color.opacity(0.9)), at: .zero, anchor: .center)
        ctx.draw(colored(text, color), at: .zero, anchor: .center)
    }

    static func colored(
        _ text: GraphicsContext.ResolvedText, _ color: Color
    ) -> GraphicsContext.ResolvedText {
        var copy = text
        copy.shading = .color(color)
        return copy
    }

    /// WIN or LOSE, on the side's own half, turned to face its player — so both
    /// verdicts read at once from opposite ends of the table.
    private static func drawVerdict(
        won: Bool, in half: CGRect, facing side: Side, color: Color,
        in context: inout GraphicsContext
    ) {
        var ctx = context
        let towardCenter = half.height * 0.22
        let y = side == .top ? half.maxY - towardCenter : half.minY + towardCenter
        ctx.translateBy(x: half.midX, y: y)
        if side == .top {
            ctx.rotate(by: .degrees(180))
        }
        let word = won ? Text("WIN", bundle: .module) : Text("LOSE", bundle: .module)
        let text = ctx.resolve(
            word.font(.system(size: half.height * 0.16, weight: .black, design: .rounded)))
        let shade = won ? color : line.opacity(0.6)
        if won {
            var haze = ctx
            haze.addFilter(.blur(radius: half.height * 0.02))
            haze.draw(colored(text, shade.opacity(0.9)), at: .zero, anchor: .center)
        }
        ctx.draw(colored(text, shade), at: .zero, anchor: .center)
    }

    /// The mallet: a glowing ring in the seat's color with a dark hollow, so
    /// it reads as a striker rather than a solid disc, and its color is
    /// unmistakably that player's.
    /// Whether a mallet ripples (a not-yet-readied seat during faceoff), and the
    /// clock + reduced-motion state that shape it.
    struct Ripple {
        var active = false
        var time: Double = 0
        var reducedMotion = false
    }

    /// A slow CRT breath over the ice — pure decoration, so it never draws under
    /// reduced motion (the caller gates it).
    private static func drawScanline(
        rect: CGRect, time: Double, in context: inout GraphicsContext
    ) {
        context.drawLayer { layer in
            layer.clip(to: Path(roundedRect: rect, cornerRadius: 8))
            layer.blendMode = .overlay
            let bandHeight = rect.height * 0.22
            let travel = rect.height + bandHeight
            let y =
                rect.minY - bandHeight + CGFloat(time.truncatingRemainder(dividingBy: 4) / 4)
                * travel
            let band = CGRect(x: rect.minX, y: y, width: rect.width, height: bandHeight)
            layer.fill(
                Path(band),
                with: .linearGradient(
                    Gradient(colors: [.clear, .white.opacity(0.06), .clear]),
                    startPoint: CGPoint(x: 0, y: band.minY),
                    endPoint: CGPoint(x: 0, y: band.maxY)))
        }
    }
}
