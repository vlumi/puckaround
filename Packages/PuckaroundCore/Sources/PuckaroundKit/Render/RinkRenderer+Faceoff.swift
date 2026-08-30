import PuckaroundCore
import SwiftUI

// MARK: - Lanes, walls & faceoff overlay

extension RinkRenderer {
    /// The border for a wrap table: solid glowing top and bottom (the goal
    /// walls), and a glowing cyan energy portal down each long side — so the
    /// openings read as sci-fi gates the puck flows through, not broken boards.
    static func drawWrapBorder(
        time: Double, reducedMotion: Bool, projection: Projection,
        in context: inout GraphicsContext
    ) {
        let rect = projection.rect
        let corner = 8 * projection.scale
        var shortWalls = Path()  // top + bottom, solid boards
        shortWalls.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        shortWalls.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        shortWalls.move(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        shortWalls.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))
        glowStroke(
            shortWalls, color: line.opacity(0.9), lineWidth: max(1.5, 1.4 * projection.scale),
            blur: 4 * projection.scale, in: &context)

        drawPortalWall(
            x: rect.minX, time: time, reducedMotion: reducedMotion,
            projection: projection, in: &context)
        drawPortalWall(
            x: rect.maxX, time: time, reducedMotion: reducedMotion,
            projection: projection, in: &context)
    }

    /// One side portal: a cyan energy gate, not a board. A soft glow band, plus a
    /// dashed core scrolling along the wall (so it reads as live, flowing energy
    /// the puck passes through). Reduced motion holds the dashes still.
    private static func drawPortalWall(
        x: CGFloat, time: Double, reducedMotion: Bool, projection: Projection,
        in context: inout GraphicsContext
    ) {
        let rect = projection.rect
        let corner = 8 * projection.scale
        var wall = Path()
        wall.move(to: CGPoint(x: x, y: rect.minY + corner))
        wall.addLine(to: CGPoint(x: x, y: rect.maxY - corner))
        let energy = SeatPalette.cyan
        // Soft outer glow band — the portal's field.
        var haze = context
        haze.addFilter(.blur(radius: 6 * projection.scale))
        haze.stroke(wall, with: .color(energy.opacity(0.5)), lineWidth: 5 * projection.scale)
        // Scrolling dashed core: the energy flowing along the gate.
        let dash = 7 * projection.scale
        let phase = reducedMotion ? 0 : CGFloat(time.truncatingRemainder(dividingBy: 2)) * dash
        context.stroke(
            wall, with: .color(energy.opacity(0.9)),
            style: StrokeStyle(
                lineWidth: max(1, 1.5 * projection.scale), dash: [dash, dash], dashPhase: phase))
    }

    /// The lane line down a doubles side: neutral furniture marking where its
    /// two mallets' zones meet, so a mallet stopping mid-half reads as a boundary,
    /// not an invisible wall. Runs that side's wall → center line, only where the
    /// side fields two, and fainter than the center line — a lesser boundary.
    static func drawLaneDividers(
        _ scene: RinkScene, projection: Projection, in context: inout GraphicsContext
    ) {
        let table = scene.rink.table
        let rect = projection.rect
        let centerY = projection.point(table.center).y
        var lines = Path()
        for side in Side.allCases where table.format.hands(on: side) == .two {
            let wallY = side == .bottom ? rect.maxY : rect.minY
            lines.move(to: CGPoint(x: rect.midX, y: wallY))
            lines.addLine(to: CGPoint(x: rect.midX, y: centerY))
        }
        guard !lines.isEmpty else { return }
        glowStroke(
            lines, color: line.opacity(0.28), lineWidth: max(1, 0.7 * projection.scale),
            blur: 3 * projection.scale, in: &context)
    }

    /// The mallets, drawn last of all — they are the players' hands, so they sit
    /// above the puck and the center menu glyph rather than hiding beneath them.
    static func drawMallets(
        _ scene: RinkScene, projection: Projection, in context: inout GraphicsContext
    ) {
        let table = scene.rink.table
        let faceoffReady = scene.rink.readyMallets
        for slot in scene.rink.slots {
            guard let mallet = scene.rink.mallet(at: slot) else { continue }
            drawMallet(
                mallet, radius: table.malletRadius, color: SeatPalette.color(for: slot.side),
                ripple: Ripple(
                    active: scene.rink.isFaceoff && !faceoffReady.contains(slot),
                    time: scene.time, reducedMotion: scene.reducedMotion),
                projection: projection, in: &context)
        }
    }

    /// The mallet: a glowing ring in the seat's color with a dark hollow, so it
    /// reads as a striker rather than a solid disc, and its color is unmistakably
    /// that player's.
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

    /// A side's faceoff readiness: a "Ready?" in each of its mallets' lanes that
    /// hasn't readied yet — so in doubles each partner sees their own prompt and
    /// knows which of them is holding up the start. The lane boundary itself is
    /// drawn as persistent furniture (see `drawLaneDividers`), so it needs none
    /// here.
    static func drawSideReadiness(
        _ scene: RinkScene, seat: Seat, half: CGRect, color: Color,
        in context: inout GraphicsContext
    ) {
        let slots = scene.rink.slots.filter { $0.side == seat.side }
        for slot in slots where !scene.rink.readyMallets.contains(slot) {
            drawReadyPrompt(
                in: laneRect(slot.lane, in: half), seat: seat, color: color, in: &context)
        }
    }

    /// The sub-rect of a side's `half` a lane occupies: the whole half for a
    /// single mallet, its left or right portion for a doubles lane.
    private static func laneRect(_ lane: Lane, in half: CGRect) -> CGRect {
        switch lane {
        case .full: return half
        case .left:
            return CGRect(x: half.minX, y: half.minY, width: half.width / 2, height: half.height)
        case .right:
            return CGRect(x: half.midX, y: half.minY, width: half.width / 2, height: half.height)
        }
    }

    private static func drawReadyPrompt(
        in half: CGRect, seat: Seat, color: Color, in context: inout GraphicsContext
    ) {
        let side = seat.side
        var ctx = context
        // Sit out toward the player's end, clear of the center where the mallet
        // starts and where the verdict (WIN/LOSE) sits — so a rematch shows both,
        // the prompt outside and the verdict in the middle.
        let fraction = 0.8
        let y =
            side == .top ? half.maxY - half.height * fraction : half.minY + half.height * fraction
        ctx.translateBy(x: half.midX, y: y)
        ctx.rotate(by: seat.labelAngle)
        let text = ctx.resolve(
            Text("Ready?", bundle: .module).font(
                .system(size: half.height * 0.1, weight: .bold, design: .rounded)))
        var haze = ctx
        haze.addFilter(.blur(radius: half.height * 0.012))
        haze.draw(colored(text, color.opacity(0.85)), at: .zero, anchor: .center)
        ctx.draw(colored(text, color.opacity(0.85)), at: .zero, anchor: .center)
    }

    /// The field BURSTING as play begins: a ring expanding out from the bubble
    /// and fading — the visual "GO". Paired with the whistle sound and haptic.
    static func drawFaceoffBurst(
        at center: CGPoint, from startRadius: CGFloat, progress: Double,
        in context: inout GraphicsContext
    ) {
        let eased = 1 - (1 - progress) * (1 - progress)  // ease-out
        let radius = startRadius * (1 + CGFloat(eased) * 2.2)
        let alpha = (1 - progress) * 0.8
        let ring = Path(
            ellipseIn: CGRect(
                x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
        glowStroke(
            ring, color: line.opacity(alpha), lineWidth: max(1, CGFloat(2 * (1 - progress)) + 1),
            blur: 6, in: &context)
    }

    /// The faceoff force field: a glowing ring around the frozen puck that no
    /// mallet may enter, breathing slowly so it reads as "live, not yet open".
    static func drawFaceoffBubble(
        around center: Vec2, radius: Double, ripple: Ripple, projection: Projection,
        in context: inout GraphicsContext
    ) {
        let p = projection.point(center)
        let pulse = ripple.reducedMotion ? 0 : sin(ripple.time * 3) * 0.06
        let r = radius * projection.scale * (1 + pulse)
        let ring = projection.disc(at: p, radius: r)
        context.fill(ring, with: .color(line.opacity(0.06)))
        glowStroke(
            ring, color: line.opacity(0.7), lineWidth: max(1.5, 1.2 * projection.scale),
            blur: 5 * projection.scale, in: &context)
    }
}
