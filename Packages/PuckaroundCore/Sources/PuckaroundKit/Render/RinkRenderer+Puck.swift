import PuckaroundCore
import SwiftUI

extension RinkRenderer {
    /// The puck: a white-hot core with a bloom, trailing a streak whose length
    /// grows with speed — a slow drift barely trails, a hard shot smears. The
    /// trail is decorative, so reduced motion shortens it to almost nothing.
    static func drawPuck(
        _ puck: Puck, radius: Double, shape: PuckShape, projection: Projection,
        in context: inout GraphicsContext
    ) {
        // Off a wrap table, or well clear of a side, the puck draws plainly. The
        // warp beam reaches out as the puck nears a portal — a wide-enough window
        // (a few radii) that it's actually seen, since the puck clears the last
        // radius in a tick or two.
        let width = projection.table.size.x
        let reach = radius * 3
        let edgeGap = min(puck.position.x, width - puck.position.x)  // dist to nearest side
        guard projection.table.sideWalls == .wrap, edgeGap < reach else {
            drawPuckInstance(
                puck, radius: radius, shape: shape, projection: projection, in: &context)
            return
        }
        // Approaching/crossing the seam. The puck keeps its own shape on each
        // side — the real one here, its copy emerging opposite — both clipped to
        // the table, with a cyan warp beam stretching between them across the
        // openings, so it reads as the puck pulled through the portal.
        var wrapped = puck
        wrapped.position.x += (puck.position.x < width / 2) ? width : -width
        let intensity = 1 - edgeGap / reach  // 0 far out → 1 at the wall
        let clip = Path(roundedRect: projection.rect, cornerRadius: 8 * projection.scale)
        context.drawLayer { layer in
            layer.clip(to: clip)
            drawWarpBeam(
                puck, radius: radius, intensity: intensity, projection: projection, in: &layer)
            drawPuckInstance(puck, radius: radius, shape: shape, projection: projection, in: &layer)
            drawPuckInstance(
                wrapped, radius: radius, shape: shape, projection: projection, in: &layer)
        }
    }

    /// The warp beam: a cyan energy tether at the puck's height, from the puck to
    /// its near portal and (clipped) mirrored in from the far one — so a crossing
    /// reads as one continuous streak. `intensity` (0→1) brightens and thickens
    /// it as the puck nears the wall. Cyan (the portal color), so it stands out
    /// against the white puck rather than washing into its bloom.
    private static func drawWarpBeam(
        _ puck: Puck, radius: Double, intensity: Double, projection: Projection,
        in context: inout GraphicsContext
    ) {
        let width = projection.table.size.x
        let toLeft = puck.position.x < width / 2
        let nearWall = toLeft ? 0.0 : width
        let farWall = toLeft ? width : 0.0
        let bands = [
            (puck.position.x, nearWall),
            (farWall, puck.position.x + (toLeft ? width : -width)),
        ]
        let r = radius * projection.scale
        let energy = SeatPalette.cyan
        for (x0, x1) in bands {
            let a = projection.point(Vec2(x0, puck.position.y))
            let b = projection.point(Vec2(x1, puck.position.y))
            var beam = Path()
            beam.move(to: a)
            beam.addLine(to: b)
            var haze = context
            haze.addFilter(.blur(radius: r * 1.1))
            haze.stroke(
                beam, with: .color(energy.opacity(0.55 * intensity)),
                style: StrokeStyle(lineWidth: r * (1 + intensity), lineCap: .round))
            context.stroke(
                beam, with: .color(energy.opacity(0.95 * intensity)),
                style: StrokeStyle(lineWidth: r * 0.6, lineCap: .round))
        }
    }

    /// Draws one copy of the puck — its trail, glowing body, and (for a disc) the
    /// spin mark — at its own position. `drawPuck` calls this once, plus a second
    /// time for the wrap ghost.
    private static func drawPuckInstance(
        _ puck: Puck, radius: Double, shape: PuckShape, projection: Projection,
        in context: inout GraphicsContext
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
        let body = puckBodyPath(puck, radius: radius, shape: shape, projection: projection)
        glow(body, color: RinkRenderer.puck, blur: 5 * projection.scale, in: &context)
        // A polygon shows its spin by its own rotation; a disc can't, so it wears
        // a small mark that turns with `angle` — off-center enough to read english
        // at a glance, without cluttering the neon core.
        if case .circle = shape {
            drawDiscSpinMark(at: p, radius: r, angle: puck.angle, in: &context)
        }
    }

    /// The disc's spin mark: a dark "clock hand" from the center to the rim,
    /// turning with `angle` — so a spinning disc visibly rotates AND shows which
    /// way (an asymmetric hand completes one turn per rotation, unlike a spoke
    /// through the center). Dark (the cabinet ground) for contrast against the
    /// bright core.
    private static func drawDiscSpinMark(
        at p: CGPoint, radius r: CGFloat, angle: Double, in context: inout GraphicsContext
    ) {
        let tip = CGPoint(x: p.x + cos(angle) * r * 0.72, y: p.y + sin(angle) * r * 0.72)
        var hand = Path()
        hand.move(to: p)
        hand.addLine(to: tip)
        context.stroke(
            hand, with: .color(RinkRenderer.ground.opacity(0.75)),
            style: StrokeStyle(lineWidth: max(1, r * 0.26), lineCap: .round))
    }

    /// The puck's outline on screen: a disc, or the rotated polygon.
    private static func puckBodyPath(
        _ puck: Puck, radius: Double, shape: PuckShape, projection: Projection
    ) -> Path {
        let vertices = shape.worldVertices(
            position: puck.position, angle: puck.angle, radius: radius)
        guard !vertices.isEmpty else {
            return projection.disc(
                at: projection.point(puck.position), radius: radius * projection.scale)
        }
        var path = Path()
        path.move(to: projection.point(vertices[0]))
        for vertex in vertices.dropFirst() {
            path.addLine(to: projection.point(vertex))
        }
        path.closeSubpath()
        return path
    }
}
