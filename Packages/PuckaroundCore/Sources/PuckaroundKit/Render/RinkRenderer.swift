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
    }

    static func draw(_ scene: RinkScene, in context: inout GraphicsContext, size: CGSize) {
        let table = scene.rink.table
        let rect = scene.tableRect
        guard rect.width > 0 else { return }
        let projection = Projection(rect: rect, scale: rect.width / table.size.x)

        // The ice.
        let iceShape = Path(roundedRect: rect, cornerRadius: 6 * projection.scale)
        context.fill(iceShape, with: .color(ice))

        // Seat bands, in each seat's color, clipped to the ice.
        let lineup = scene.rink.lineup
        let zones = SeatZones(lineup: lineup, bounds: table.bounds)
        let depth = min(table.size.x, table.size.y) * 0.08
        context.drawLayer { layer in
            layer.clip(to: iceShape)
            for player in lineup.players {
                let band = projection.rect(zones.band(for: player, depth: depth))
                layer.fill(
                    Path(band),
                    with: .color(SeatPalette.color(for: player, in: lineup).opacity(0.35)))
            }
        }

        drawMarkings(for: table, projection: projection, in: &context)
        drawPuck(scene.rink.puck, radius: table.puckRadius, projection: projection, in: &context)
    }

    /// Centre ring and the midline across the table's long axis.
    private static func drawMarkings(
        for table: Playfield, projection: Projection, in context: inout GraphicsContext
    ) {
        let centre = projection.point(table.center)
        let ring = 10 * projection.scale
        let lineWidth = max(1, 0.6 * projection.scale)
        context.stroke(
            Path(
                ellipseIn: CGRect(
                    x: centre.x - ring, y: centre.y - ring, width: 2 * ring, height: 2 * ring)),
            with: .color(lines), lineWidth: lineWidth)
        var midline = Path()
        if table.size.y >= table.size.x {
            midline.move(to: CGPoint(x: projection.rect.minX, y: centre.y))
            midline.addLine(to: CGPoint(x: projection.rect.maxX, y: centre.y))
        } else {
            midline.move(to: CGPoint(x: centre.x, y: projection.rect.minY))
            midline.addLine(to: CGPoint(x: centre.x, y: projection.rect.maxY))
        }
        context.stroke(midline, with: .color(lines), lineWidth: lineWidth)
    }

    /// A dark disc with a small highlight so its motion reads.
    private static func drawPuck(
        _ puck: Puck, radius: Double, projection: Projection, in context: inout GraphicsContext
    ) {
        let p = projection.point(puck.position)
        let r = radius * projection.scale
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
            with: .color(RinkRenderer.puck))
        let h = r * 0.35
        context.fill(
            Path(
                ellipseIn: CGRect(
                    x: p.x - r * 0.45 - h / 2, y: p.y - r * 0.45 - h / 2, width: h, height: h)),
            with: .color(Color.white.opacity(0.25)))
    }
}
