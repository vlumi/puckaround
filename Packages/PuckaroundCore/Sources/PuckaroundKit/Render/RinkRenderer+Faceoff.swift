import PuckaroundCore
import SwiftUI

// MARK: - Faceoff overlay

extension RinkRenderer {
    /// A side's faceoff readiness: a "Ready?" in each of its mallets' lanes that
    /// hasn't readied yet — so in doubles each partner sees their own prompt and
    /// knows which of them is holding up the start — with a hairline splitting
    /// the two lanes when the side fields two.
    static func drawSideReadiness(
        _ scene: RinkScene, side: Side, half: CGRect, color: Color,
        in context: inout GraphicsContext
    ) {
        let slots = scene.rink.slots.filter { $0.side == side }
        let rematch = scene.rink.finalWinner != nil
        if slots.count > 1 {
            // Split the half down the centre line so each partner has a segment.
            var rule = Path()
            rule.move(to: CGPoint(x: half.midX, y: half.minY))
            rule.addLine(to: CGPoint(x: half.midX, y: half.maxY))
            context.stroke(rule, with: .color(color.opacity(0.25)), lineWidth: 1)
        }
        for slot in slots where !scene.rink.readyMallets.contains(slot) {
            drawReadyPrompt(
                rematch: rematch, in: laneRect(slot.lane, in: half), facing: side, color: color,
                in: &context)
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
        rematch: Bool, in half: CGRect, facing side: Side, color: Color,
        in context: inout GraphicsContext
    ) {
        var ctx = context
        // On a rematch the verdict sits near the centre line, so the prompt
        // drops toward the player to clear it; the opening faceoff centres it.
        let fraction = rematch ? 0.6 : 0.5
        let y =
            side == .top ? half.maxY - half.height * fraction : half.minY + half.height * fraction
        ctx.translateBy(x: half.midX, y: y)
        if side == .top {
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

    /// The field BURSTING as play begins: a ring expanding out from the bubble
    /// and fading — the visual "GO". Paired with the whistle sound and haptic.
    static func drawFaceoffBurst(
        at centre: CGPoint, from startRadius: CGFloat, progress: Double,
        in context: inout GraphicsContext
    ) {
        let eased = 1 - (1 - progress) * (1 - progress)  // ease-out
        let radius = startRadius * (1 + CGFloat(eased) * 2.2)
        let alpha = (1 - progress) * 0.8
        let ring = Path(
            ellipseIn: CGRect(
                x: centre.x - radius, y: centre.y - radius, width: 2 * radius, height: 2 * radius))
        glowStroke(
            ring, color: line.opacity(alpha), lineWidth: max(1, CGFloat(2 * (1 - progress)) + 1),
            blur: 6, in: &context)
    }

    /// The faceoff force field: a glowing ring around the frozen puck that no
    /// mallet may enter, breathing slowly so it reads as "live, not yet open".
    static func drawFaceoffBubble(
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
