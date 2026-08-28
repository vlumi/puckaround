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
}

/// **Neon cabinet.** A dark playfield that glows: a neutral rink (ice, grid,
/// centre line, puck) that belongs to no seat, and the two players' colours on
/// exactly the three things that are theirs — mallet, goal, score. Glow is
/// additive over a solid core, so a hard puck and a readable score survive the
/// bloom. All procedural; no assets. Being a committed dark look, it has no
/// light variant.
enum RinkRenderer {
    /// The cabinet the table sits in — a near-black with a faint violet bias.
    static let ground = Color(red: 0.039, green: 0.024, blue: 0.071)
    /// The ice: a dark neutral playfield, not white — the glow does the lifting.
    static let ice = Color(red: 0.071, green: 0.043, blue: 0.122)
    /// Rink furniture: grid, centre line, ring. A cool neutral owned by nobody.
    static let line = Color(red: 0.60, green: 0.72, blue: 0.95)
    /// The puck: white-hot, so it reads against every seat colour and the ice.
    static let puck = Color(red: 0.97, green: 0.96, blue: 1.0)

    /// The centre ring's radius in world units — the menu button. Shared so the
    /// touch target (in the view) matches the drawn ring exactly.
    static let centreRingRadius: Double = 16

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

    /// A glowing fill: the shape drawn once blurred (the bloom) and once solid
    /// (the core), so the colour stays legible while still emitting.
    private static func glow(
        _ path: Path, color: Color, blur: CGFloat, core: Double = 1,
        in context: inout GraphicsContext
    ) {
        var haze = context
        haze.addFilter(.blur(radius: blur))
        haze.fill(path, with: .color(color.opacity(0.9)))
        context.fill(path, with: .color(color.opacity(core)))
    }

    private static func glowStroke(
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
        let lineup = scene.rink.lineup

        drawRink(projection: projection, in: &context)
        let faceoffReady = scene.rink.readySeats
        for player in lineup.players {
            let edge = lineup.seat(of: player)
            let color = SeatPalette.color(for: player, in: lineup)
            drawScore(
                scene.rink.score(of: player), at: edge, color: color,
                projection: projection, in: &context)
            drawGoal(at: edge, color: color, projection: projection, in: &context)
            let half = projection.rect(table.malletZone(for: edge))
            // The result of the game just played stays up through the rematch
            // faceoff, so players see who won while deciding to go again.
            if let winner = scene.rink.finalWinner {
                drawVerdict(
                    won: winner == player, in: half, facing: edge, color: color, in: &context)
            }
            // A seat that hasn't readied is prompted to — "Ready?" to open, or a
            // rematch invite once a game is over.
            if scene.rink.isFaceoff, !faceoffReady.contains(player) {
                drawReadyPrompt(
                    rematch: scene.rink.finalWinner != nil, in: half, facing: edge, color: color,
                    in: &context)
            }
            drawMallet(
                scene.rink.mallet(of: player), radius: table.malletRadius, color: color,
                ripple: Ripple(
                    active: scene.rink.isFaceoff && !faceoffReady.contains(player),
                    time: scene.time, reducedMotion: scene.reducedMotion),
                projection: projection, in: &context)
        }
        // The menu glyph is always there — the centre ring is always the menu.
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
        drawPuck(scene.rink.puck, radius: table.puckRadius, projection: projection, in: &context)
        if !scene.reducedMotion {
            drawScanline(rect: rect, time: scene.time, in: &context)
        }
    }

    /// The ice, a faint neutral grid clipped to it, and a glowing border +
    /// centre line — all neutral, so the rink belongs to no player.
    private static func drawRink(projection: Projection, in context: inout GraphicsContext) {
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

        glowStroke(
            iceShape, color: line.opacity(0.9), lineWidth: max(1.5, 1.4 * projection.scale),
            blur: 4 * projection.scale, in: &context)

        // The centre line is INTERRUPTED by the centre circle — as on a real
        // rink — so it runs edge → ring on each side and leaves the ring's
        // interior clean for the puck and the menu glyph.
        let centre = projection.point(projection.table.center)
        let ringRadius = centreRingRadius * projection.scale
        var midline = Path()
        midline.move(to: CGPoint(x: rect.minX, y: centre.y))
        midline.addLine(to: CGPoint(x: centre.x - ringRadius, y: centre.y))
        midline.move(to: CGPoint(x: centre.x + ringRadius, y: centre.y))
        midline.addLine(to: CGPoint(x: rect.maxX, y: centre.y))
        let ring = projection.disc(at: centre, radius: ringRadius)
        glowStroke(
            midline, color: line.opacity(0.55), lineWidth: max(1, 0.8 * projection.scale),
            blur: 3 * projection.scale, in: &context)
        glowStroke(
            ring, color: line.opacity(0.55), lineWidth: max(1, 0.8 * projection.scale),
            blur: 3 * projection.scale, in: &context)
    }

    /// A hamburger inside the centre ring — the menu affordance, so the centre
    /// tap target is discoverable. Three short bars, neutral (they read the same
    /// from both ends). Always drawn (the ring is always the menu); it sits
    /// under the puck, which rests on it during a faceoff.
    private static func drawMenuGlyph(projection: Projection, in context: inout GraphicsContext) {
        let centre = projection.point(projection.table.center)
        let barWidth = 15 * projection.scale
        let barGap = 5.5 * projection.scale
        var bars = Path()
        for row in -1...1 {
            let y = centre.y + CGFloat(row) * barGap
            bars.move(to: CGPoint(x: centre.x - barWidth / 2, y: y))
            bars.addLine(to: CGPoint(x: centre.x + barWidth / 2, y: y))
        }
        context.stroke(
            bars, with: .color(line.opacity(0.6)),
            style: StrokeStyle(lineWidth: max(2, 2 * projection.scale), lineCap: .round))
    }

    /// The goal mouth: a glowing bar in the seat's own colour, set into its
    /// short wall — one of the three things that colour owns.
    private static func drawGoal(
        at edge: Seat, color: Color, projection: Projection, in context: inout GraphicsContext
    ) {
        let table = projection.table
        let width = table.goalWidth * projection.scale
        let x = projection.rect.midX - width / 2
        let y: CGFloat
        switch edge {
        case .top: y = projection.rect.minY
        case .bottom: y = projection.rect.maxY
        case .left, .right: return
        }
        var bar = Path()
        bar.move(to: CGPoint(x: x, y: y))
        bar.addLine(to: CGPoint(x: x + width, y: y))
        glowStroke(
            bar, color: color, lineWidth: max(3, 2.4 * projection.scale),
            blur: 5 * projection.scale, in: &context)
    }

    /// The seat's score, in the corner beside its goal, turned to face its
    /// player — a bright core over a glow, so a glanced number stays legible.
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
        let text = ctx.resolve(
            Text(verbatim: "\(score)").font(
                .system(size: 15 * projection.scale, weight: .black, design: .rounded)))
        var haze = ctx
        haze.addFilter(.blur(radius: 4 * projection.scale))
        haze.draw(coloured(text, color.opacity(0.9)), at: .zero, anchor: .center)
        ctx.draw(coloured(text, color), at: .zero, anchor: .center)
    }

    private static func coloured(
        _ text: GraphicsContext.ResolvedText, _ color: Color
    ) -> GraphicsContext.ResolvedText {
        var copy = text
        copy.shading = .color(color)
        return copy
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
        let text = ctx.resolve(
            word.font(.system(size: half.height * 0.16, weight: .black, design: .rounded)))
        let shade = won ? color : line.opacity(0.6)
        if won {
            var haze = ctx
            haze.addFilter(.blur(radius: half.height * 0.02))
            haze.draw(coloured(text, shade.opacity(0.9)), at: .zero, anchor: .center)
        }
        ctx.draw(coloured(text, shade), at: .zero, anchor: .center)
    }

    /// The mallet: a glowing ring in the seat's colour with a dark hollow, so
    /// it reads as a striker rather than a solid disc, and its colour is
    /// unmistakably that player's.
    /// Whether a mallet ripples (a not-yet-readied seat during faceoff), and the
    /// clock + reduced-motion state that shape it.
    private struct Ripple {
        var active = false
        var time: Double = 0
        var reducedMotion = false
    }

    private static func drawMallet(
        _ mallet: Mallet, radius: Double, color: Color, ripple: Ripple = Ripple(),
        projection: Projection, in context: inout GraphicsContext
    ) {
        let p = projection.point(mallet.position)
        let r = radius * projection.scale
        // Before a seat readies, a slow ripple pulses out from its mallet — a
        // wordless "grab me". Off under reduced motion (a static soft halo).
        if ripple.active {
            let phase =
                ripple.reducedMotion ? 0.5 : (ripple.time * 0.8).truncatingRemainder(dividingBy: 1)
            let rippleR = r * (1 + phase * 1.6)
            context.stroke(
                projection.disc(at: p, radius: rippleR),
                with: .color(color.opacity((1 - phase) * 0.5)),
                lineWidth: max(1, 0.5 * projection.scale))
        }
        glow(
            projection.disc(at: p, radius: r), color: color, blur: 6 * projection.scale, core: 1,
            in: &context)
        context.fill(projection.disc(at: p, radius: r * 0.5), with: .color(ground.opacity(0.85)))
        context.stroke(
            projection.disc(at: p, radius: r * 0.5), with: .color(color.opacity(0.6)),
            lineWidth: max(1, 0.4 * projection.scale))
    }

    /// The puck: a white-hot core with a bloom, trailing a streak whose length
    /// grows with speed — a slow drift barely trails, a hard shot smears. The
    /// trail is decorative, so reduced motion shortens it to almost nothing.
    private static func drawPuck(
        _ puck: Puck, radius: Double, projection: Projection, in context: inout GraphicsContext
    ) {
        let p = projection.point(puck.position)
        let r = radius * projection.scale
        let speed = puck.velocity.length
        // Trail only earns its place at pace: near-zero slow, a few puck-lengths fast.
        let trailLength = min(6, speed / 60) * r
        if trailLength > r * 0.5 {
            let dir = puck.velocity.normalized
            let tail = CGPoint(x: p.x - dir.x * trailLength, y: p.y - dir.y * trailLength)
            var streak = Path()
            streak.move(to: p)
            streak.addLine(to: tail)
            var haze = context
            haze.addFilter(.blur(radius: r * 0.6))
            haze.stroke(
                streak, with: .color(RinkRenderer.puck.opacity(0.35)),
                style: StrokeStyle(lineWidth: r * 1.2, lineCap: .round))
        }
        glow(
            projection.disc(at: p, radius: r), color: RinkRenderer.puck, blur: 5 * projection.scale,
            in: &context)
        context.fill(
            projection.disc(at: CGPoint(x: p.x - r * 0.4, y: p.y - r * 0.4), radius: r * 0.22),
            with: .color(.white))
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

// MARK: - Faceoff overlay

extension RinkRenderer {
    /// "Ready?" on the board in the seat's half, facing its player — the prompt
    /// to tap in. Disappears the moment that seat has readied.
    private static func drawReadyPrompt(
        rematch: Bool, in half: CGRect, facing edge: Seat, color: Color,
        in context: inout GraphicsContext
    ) {
        var ctx = context
        // On a rematch the verdict sits near the centre line, so the prompt
        // drops toward the player to clear it; the opening faceoff centres it.
        let fraction = rematch ? 0.6 : 0.5
        let y =
            edge == .top ? half.maxY - half.height * fraction : half.minY + half.height * fraction
        ctx.translateBy(x: half.midX, y: y)
        if edge == .top {
            ctx.rotate(by: .degrees(180))
        }
        let text = ctx.resolve(
            Text("Ready?", bundle: .module).font(
                .system(size: half.height * 0.1, weight: .bold, design: .rounded)))
        var haze = ctx
        haze.addFilter(.blur(radius: half.height * 0.012))
        haze.draw(coloured(text, color.opacity(0.85)), at: .zero, anchor: .center)
        ctx.draw(coloured(text, color.opacity(0.85)), at: .zero, anchor: .center)
    }

    /// The faceoff force field: a glowing ring around the frozen puck that no
    /// mallet may enter, breathing slowly so it reads as "live, not yet open".
    private static func drawFaceoffBubble(
        around centre: Vec2, radius: Double, ripple: Ripple, projection: Projection,
        in context: inout GraphicsContext
    ) {
        let p = projection.point(centre)
        let pulse = ripple.reducedMotion ? 0 : sin(ripple.time * 3) * 0.06
        let r = radius * projection.scale * (1 + pulse)
        let ring = projection.disc(at: p, radius: r)
        context.fill(ring, with: .color(line.opacity(0.06)))
        glowStroke(
            ring, color: line.opacity(0.7), lineWidth: max(1.5, 1.2 * projection.scale),
            blur: 5 * projection.scale, in: &context)
    }
}
