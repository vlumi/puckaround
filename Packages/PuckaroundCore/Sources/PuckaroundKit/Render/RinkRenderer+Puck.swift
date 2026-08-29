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
