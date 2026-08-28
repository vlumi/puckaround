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
        // A circle needs a highlight to show it is moving at all; a polygon
        // shows its spin by its own rotation, so it needs none (an offset dot
        // just reads as a stray mark on the small shape).
        if case .circle = shape {
            context.fill(
                projection.disc(
                    at: CGPoint(x: p.x - r * 0.4, y: p.y - r * 0.4), radius: r * 0.22),
                with: .color(.white))
        }
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
