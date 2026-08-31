import PuckaroundCore
import SwiftUI

extension RinkRenderer {
    /// The puck: a white-hot core with a bloom, trailing a streak whose length
    /// grows with speed — a slow drift barely trails, a hard shot smears. The
    /// trail is decorative, so reduced motion shortens it to almost nothing.
    static func drawPuck(
        _ puck: Puck, radius: Double, projection: Projection,
        in context: inout GraphicsContext
    ) {
        // Off a wrap table, or not yet straddling a side, the puck draws plainly.
        // It only warps while its disc actually spans the seam (center within a
        // radius of a wall), so part shows on each side.
        let width = projection.table.size.x
        let edgeGap = min(puck.position.x, width - puck.position.x)  // dist to nearest side
        guard projection.table.sideWalls == .wrap, edgeGap < radius else {
            drawPuckInstance(puck, radius: radius, projection: projection, in: &context)
            return
        }
        // Straddling the seam: the puck is warping through at light speed, so the
        // GAP between its two halves (the part racing off each screen edge)
        // stretches outward. Each side keeps the puck at its own position but
        // elongated toward its near edge; both are clipped to the table, so it
        // reads as one streak snapping across the portal.
        var wrapped = puck
        wrapped.position.x += (puck.position.x < width / 2) ? width : -width
        // Deeper into the crossing (center nearer the wall) → longer streak.
        let stretch = 1 + (1 - edgeGap / radius) * 2.5  // 1 → 3.5 at the wall
        let clip = Path(roundedRect: projection.rect, cornerRadius: 8 * projection.scale)
        context.drawLayer { layer in
            layer.clip(to: clip)
            for image in [puck, wrapped] {
                // Each half stretches along x toward its near wall — the
                // light-speed smear. Anchor at the trailing rim (away from the
                // wall) so the leading edge races off the screen edge, widening
                // the gap between the two halves. "Near" is by table half, so a
                // real puck a hair inside the left wall stretches left, not right.
                let p = projection.point(image.position)
                let towardWall: CGFloat = image.position.x < width / 2 ? -1 : 1
                let anchorX = p.x - towardWall * radius * projection.scale
                var ctx = layer
                ctx.translateBy(x: anchorX, y: p.y)
                ctx.scaleBy(x: stretch, y: 1)
                ctx.translateBy(x: -anchorX, y: -p.y)
                drawPuckInstance(image, radius: radius, projection: projection, in: &ctx)
            }
        }
    }

    /// Draws one copy of the puck — its trail, glowing body, and (for a disc) the
    /// spin mark — at its own position. `drawPuck` calls this once, plus a second
    /// time for the wrap ghost.
    private static func drawPuckInstance(
        _ puck: Puck, radius: Double, projection: Projection,
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
        let body = puckBodyPath(puck, radius: radius, projection: projection)
        glow(body, color: RinkRenderer.puck, blur: 5 * projection.scale, in: &context)
        // A polygon shows its spin by its own rotation; a disc can't, so it wears
        // a small mark that turns with `angle` — off-center enough to read english
        // at a glance, without cluttering the neon core.
        if case .circle = puck.shape {
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
        _ puck: Puck, radius: Double, projection: Projection
    ) -> Path {
        let vertices = puck.shape.worldVertices(
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
