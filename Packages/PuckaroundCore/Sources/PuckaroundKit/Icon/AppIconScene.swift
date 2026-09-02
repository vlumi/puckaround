import PuckaroundCore
import SwiftUI

/// The app icon, drawn by the game's own recipe — the neon cabinet shrunk to
/// a tile, holding the game's true orientation: magenta at your end, cyan
/// defending the top. The moment is a rally — the puck fired from deep in
/// the magenta corner, streaking across the ring while cyan falls back to
/// its mouth. Chosen from six candidates for how it balances at small sizes
/// (the off-center diagonal reads better tiny than the centered marks). No
/// image assets: `make icon` renders this at 1024×1024 into the asset
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

            // Center line + ring.
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

            // Goal mouths, the game's own way up: cyan defends the top,
            // magenta — you — the bottom.
            let goalW = 300.0 * s
            func goal(y: CGFloat, color: Color) {
                var bar = Path()
                bar.move(to: CGPoint(x: size.width / 2 - goalW / 2, y: y))
                bar.addLine(to: CGPoint(x: size.width / 2 + goalW / 2, y: y))
                glowStroke(bar, color: color, width: 18 * s, blur: 22 * s, in: &context)
            }
            goal(y: rink.minY, color: SeatPalette.cyan)
            goal(y: rink.maxY, color: SeatPalette.magenta)

            // The rally: the magenta mallet deep in its corner has just
            // fired; cyan falls back toward its mouth.
            mallet(
                CGPoint(x: size.width * 0.30, y: rink.minY + rink.height * 0.80), 100 * s,
                SeatPalette.magenta, s: s, in: &context)
            mallet(
                CGPoint(x: size.width * 0.68, y: rink.minY + rink.height * 0.15), 88 * s,
                SeatPalette.cyan, s: s, in: &context)

            // The white-hot puck mid-flight, its streak trailing back to the
            // striker.
            let puckAt = CGPoint(x: size.width * 0.56, y: size.height * 0.42)
            var streak = Path()
            streak.move(to: puckAt)
            streak.addLine(to: CGPoint(x: puckAt.x - 190 * s, y: puckAt.y + 260 * s))
            var haze = context
            haze.addFilter(.blur(radius: 40 * s))
            haze.stroke(
                streak, with: .color(RinkRenderer.puck.opacity(0.4)),
                style: StrokeStyle(lineWidth: 74 * s, lineCap: .round))
            glowDisc(puckAt, 62 * s, RinkRenderer.puck, blur: 28 * s, in: &context)
            // The specular glint, up-left like every light in the cabinet.
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
