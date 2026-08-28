import PuckaroundCore
import SwiftUI

/// The app icon, drawn by the game's own recipe — the neon cabinet shrunk to a
/// tile: the glowing rink, its two goal mouths in the seat colours, the two
/// mallets facing off across the centre line, and a white-hot puck in the
/// slot. No image assets: `make icon` renders this at 1024×1024 into the asset
/// catalog. It must keep matching how `RinkRenderer` draws the real table.
public struct AppIconScene: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            let s = size.width / 1024  // designed at 1024
            let full = CGRect(origin: .zero, size: size)

            // Cabinet ground.
            context.fill(Path(full), with: .color(RinkRenderer.ground))

            // The rink, inset with a soft margin, with a faint grid.
            let rink = full.insetBy(dx: 150 * s, dy: 150 * s)
            let iceShape = Path(roundedRect: rink, cornerRadius: 64 * s)
            context.fill(iceShape, with: .color(RinkRenderer.ice))
            context.drawLayer { layer in
                layer.clip(to: iceShape)
                var grid = Path()
                var gx = rink.minX
                while gx <= rink.maxX {
                    grid.move(to: CGPoint(x: gx, y: rink.minY))
                    grid.addLine(to: CGPoint(x: gx, y: rink.maxY))
                    gx += 64 * s
                }
                var gy = rink.minY
                while gy <= rink.maxY {
                    grid.move(to: CGPoint(x: rink.minX, y: gy))
                    grid.addLine(to: CGPoint(x: rink.maxX, y: gy))
                    gy += 64 * s
                }
                layer.stroke(grid, with: .color(RinkRenderer.line.opacity(0.12)), lineWidth: 2 * s)
            }
            glowStroke(
                iceShape, color: RinkRenderer.line.opacity(0.85), width: 10 * s, blur: 20 * s,
                in: &context)

            // Centre line + ring.
            let mid = size.height / 2
            var midline = Path()
            midline.move(to: CGPoint(x: rink.minX, y: mid))
            midline.addLine(to: CGPoint(x: rink.maxX, y: mid))
            glowStroke(
                midline, color: RinkRenderer.line.opacity(0.5), width: 6 * s, blur: 14 * s,
                in: &context)
            let ring = disc(CGPoint(x: size.width / 2, y: mid), 120 * s)
            glowStroke(
                ring, color: RinkRenderer.line.opacity(0.5), width: 6 * s, blur: 14 * s,
                in: &context)

            // Goal mouths, each in its seat colour.
            let goalW = 300.0 * s
            func goal(y: CGFloat, color: Color) {
                var bar = Path()
                bar.move(to: CGPoint(x: size.width / 2 - goalW / 2, y: y))
                bar.addLine(to: CGPoint(x: size.width / 2 + goalW / 2, y: y))
                glowStroke(bar, color: color, width: 18 * s, blur: 22 * s, in: &context)
            }
            goal(y: rink.minY, color: SeatPalette.magenta)
            goal(y: rink.maxY, color: SeatPalette.cyan)

            // Two mallets, facing off — magenta top, cyan bottom, matching the
            // goals. Set off-centre and NOT mirrored: the top one drawn back and
            // to one side, the bottom one nearer the centre on the other, so the
            // icon reads as a moment of play rather than a symmetric diagram.
            mallet(
                CGPoint(x: size.width * 0.37, y: rink.minY + rink.height * 0.23), 96 * s,
                SeatPalette.magenta, s: s, in: &context)
            mallet(
                CGPoint(x: size.width * 0.61, y: rink.minY + rink.height * 0.63), 96 * s,
                SeatPalette.cyan, s: s, in: &context)

            // The white-hot puck, off centre toward the cyan mallet, trailing
            // back toward the magenta one.
            let puckAt = CGPoint(x: size.width * 0.53, y: mid - 26 * s)
            var streak = Path()
            streak.move(to: puckAt)
            streak.addLine(to: CGPoint(x: puckAt.x - 150 * s, y: puckAt.y - 120 * s))
            var haze = context
            haze.addFilter(.blur(radius: 40 * s))
            haze.stroke(
                streak, with: .color(RinkRenderer.puck.opacity(0.4)),
                style: StrokeStyle(lineWidth: 70 * s, lineCap: .round))
            glowDisc(puckAt, 60 * s, RinkRenderer.puck, blur: 28 * s, in: &context)
            context.fill(
                disc(CGPoint(x: puckAt.x - 22 * s, y: puckAt.y - 22 * s), 16 * s),
                with: .color(.white))
        }
    }

    private func disc(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    private func glowStroke(
        _ path: Path, color: Color, width: CGFloat, blur: CGFloat, in context: inout GraphicsContext
    ) {
        var haze = context
        haze.addFilter(.blur(radius: blur))
        haze.stroke(path, with: .color(color.opacity(0.85)), lineWidth: width)
        context.stroke(path, with: .color(color), lineWidth: width)
    }

    private func glowDisc(
        _ c: CGPoint, _ r: CGFloat, _ color: Color, blur: CGFloat, in context: inout GraphicsContext
    ) {
        var haze = context
        haze.addFilter(.blur(radius: blur))
        haze.fill(disc(c, r), with: .color(color.opacity(0.9)))
        context.fill(disc(c, r), with: .color(color))
    }

    private func mallet(
        _ c: CGPoint, _ r: CGFloat, _ color: Color, s: CGFloat, in context: inout GraphicsContext
    ) {
        glowDisc(c, r, color, blur: 26 * s, in: &context)
        context.fill(disc(c, r * 0.5), with: .color(RinkRenderer.ground.opacity(0.85)))
        context.stroke(disc(c, r * 0.5), with: .color(color.opacity(0.6)), lineWidth: 4 * s)
    }
}
