import PuckaroundCore
import SwiftUI

/// Which composition the icon draws. `classic` is the shipped look (its
/// colors predate the magenta-is-the-bottom convention); the others are
/// candidates that keep the game's orientation — magenta down, cyan up —
/// rendered side by side by the icon tool for comparison.
public enum IconVariant: String, CaseIterable, Sendable {
    /// The shipped icon: magenta top (flipped vs play), staggered mallets.
    case classic
    /// The classic composition with the game's true orientation.
    case corrected
    /// A strong diagonal: the magenta mallet has just fired from deep, the
    /// puck streaks across the ring at the cyan end's guard.
    case rally
    /// The opening ceremony: the puck frozen at center behind the force
    /// field, both mallets waiting — calm, symmetric, legible when tiny.
    case faceoff
    /// A close-up of the strike: one big magenta mallet low, the puck just
    /// away and burning toward the cyan goal.
    case strike
    /// No mallets at all: the rink, the two goal mouths, one streaking puck.
    case minimal
}

/// The app icon, drawn by the game's own recipe — the neon cabinet shrunk to
/// a tile: the glowing rink, its goal mouths in the seat colors, mallets and
/// a white-hot puck. No image assets: `make icon` renders this at 1024×1024
/// into the asset catalog. It must keep matching how `RinkRenderer` draws the
/// real table.
public struct AppIconScene: View {
    let variant: IconVariant

    public init(variant: IconVariant = .classic) {
        self.variant = variant
    }

    public var body: some View {
        Canvas { context, size in
            let s = size.width / 1024  // designed at 1024
            drawChrome(&context, size: size, s: s)
            switch variant {
            case .classic: drawClassic(&context, size: size, s: s)
            case .corrected: drawCorrected(&context, size: size, s: s)
            case .rally: drawRally(&context, size: size, s: s)
            case .faceoff: drawFaceoff(&context, size: size, s: s)
            case .strike: drawStrike(&context, size: size, s: s)
            case .minimal: drawMinimal(&context, size: size, s: s)
            }
        }
    }

    /// How far the rink insets from the tile edge — the close-up crops tighter.
    private var rinkInset: CGFloat { variant == .strike ? 110 : 150 }

    /// The stage every variant shares: ground, rink, grid, center furniture,
    /// and the two goal mouths — cyan up, magenta down, as the game holds
    /// them (the classic variant flips its own goals afterward).
    private func drawChrome(_ context: inout GraphicsContext, size: CGSize, s: CGFloat) {
        let full = CGRect(origin: .zero, size: size)
        context.fill(Path(full), with: .color(RinkRenderer.ground))
        let rink = full.insetBy(dx: rinkInset * s, dy: rinkInset * s)
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

        let mid = size.height / 2
        var midline = Path()
        midline.move(to: CGPoint(x: rink.minX, y: mid))
        midline.addLine(to: CGPoint(x: rink.maxX, y: mid))
        glowStroke(
            midline, color: RinkRenderer.line.opacity(0.5), width: 6 * s, blur: 14 * s,
            in: &context)
        let ring = disc(CGPoint(x: size.width / 2, y: mid), 120 * s)
        glowStroke(
            ring, color: RinkRenderer.line.opacity(0.5), width: 6 * s, blur: 14 * s, in: &context)

        // Goal mouths in the game's own orientation; classic re-flips below.
        let top = variant == .classic ? SeatPalette.magenta : SeatPalette.cyan
        let bottom = variant == .classic ? SeatPalette.cyan : SeatPalette.magenta
        goal(y: rink.minY, color: top, size: size, s: s, in: &context)
        goal(y: rink.maxY, color: bottom, size: size, s: s, in: &context)
    }

    /// The shipped composition, colors as shipped (magenta up).
    private func drawClassic(_ context: inout GraphicsContext, size: CGSize, s: CGFloat) {
        let rink = CGRect(origin: .zero, size: size).insetBy(dx: 150 * s, dy: 150 * s)
        mallet(
            CGPoint(x: size.width * 0.37, y: rink.minY + rink.height * 0.23), 96 * s,
            SeatPalette.magenta, s: s, in: &context)
        mallet(
            CGPoint(x: size.width * 0.61, y: rink.minY + rink.height * 0.63), 96 * s,
            SeatPalette.cyan, s: s, in: &context)
        let puckAt = CGPoint(x: size.width * 0.53, y: size.height / 2 - 26 * s)
        streakingPuck(
            at: puckAt, radius: 60 * s, from: CGPoint(x: puckAt.x - 150 * s, y: puckAt.y - 120 * s),
            s: s, in: &context)
    }

    /// The same moment with the game's orientation: the magenta mallet (yours,
    /// near the ring) has just sent the puck up toward the cyan end's guard.
    private func drawCorrected(_ context: inout GraphicsContext, size: CGSize, s: CGFloat) {
        let rink = CGRect(origin: .zero, size: size).insetBy(dx: 150 * s, dy: 150 * s)
        mallet(
            CGPoint(x: size.width * 0.37, y: rink.minY + rink.height * 0.23), 96 * s,
            SeatPalette.cyan, s: s, in: &context)
        mallet(
            CGPoint(x: size.width * 0.61, y: rink.minY + rink.height * 0.70), 96 * s,
            SeatPalette.magenta, s: s, in: &context)
        let puckAt = CGPoint(x: size.width * 0.51, y: size.height / 2 - 40 * s)
        streakingPuck(
            at: puckAt, radius: 60 * s, from: CGPoint(x: puckAt.x + 110 * s, y: puckAt.y + 170 * s),
            s: s, in: &context)
    }

    /// A hard diagonal: fired from deep in the magenta corner, streaking
    /// across the ring; the cyan mallet falls back toward its mouth.
    private func drawRally(_ context: inout GraphicsContext, size: CGSize, s: CGFloat) {
        let rink = CGRect(origin: .zero, size: size).insetBy(dx: 150 * s, dy: 150 * s)
        mallet(
            CGPoint(x: size.width * 0.30, y: rink.minY + rink.height * 0.80), 100 * s,
            SeatPalette.magenta, s: s, in: &context)
        mallet(
            CGPoint(x: size.width * 0.68, y: rink.minY + rink.height * 0.15), 88 * s,
            SeatPalette.cyan, s: s, in: &context)
        let puckAt = CGPoint(x: size.width * 0.56, y: size.height * 0.42)
        streakingPuck(
            at: puckAt, radius: 62 * s, from: CGPoint(x: puckAt.x - 190 * s, y: puckAt.y + 260 * s),
            s: s, in: &context)
    }

    /// The faceoff: the puck frozen at center behind the force field, both
    /// mallets squared up on their line. The calmest and most symmetric read.
    private func drawFaceoff(_ context: inout GraphicsContext, size: CGSize, s: CGFloat) {
        let rink = CGRect(origin: .zero, size: size).insetBy(dx: 150 * s, dy: 150 * s)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        // The force field, breathing around the ring.
        let bubble = disc(center, 190 * s)
        context.fill(bubble, with: .color(RinkRenderer.line.opacity(0.06)))
        glowStroke(
            bubble, color: RinkRenderer.line.opacity(0.7), width: 8 * s, blur: 24 * s,
            in: &context)
        mallet(
            CGPoint(x: size.width * 0.55, y: rink.minY + rink.height * 0.22), 96 * s,
            SeatPalette.cyan, s: s, in: &context)
        mallet(
            CGPoint(x: size.width * 0.45, y: rink.minY + rink.height * 0.78), 96 * s,
            SeatPalette.magenta, s: s, in: &context)
        glowDisc(center, 58 * s, RinkRenderer.puck, blur: 28 * s, in: &context)
        context.fill(
            disc(CGPoint(x: center.x - 20 * s, y: center.y - 20 * s), 15 * s),
            with: .color(.white))
    }

    /// The strike, close up: your mallet fills the low half, the puck just
    /// away and burning for the cyan mouth.
    private func drawStrike(_ context: inout GraphicsContext, size: CGSize, s: CGFloat) {
        let rink = CGRect(origin: .zero, size: size).insetBy(dx: rinkInset * s, dy: rinkInset * s)
        mallet(
            CGPoint(x: size.width * 0.40, y: rink.minY + rink.height * 0.74), 150 * s,
            SeatPalette.magenta, s: s, in: &context)
        mallet(
            CGPoint(x: size.width * 0.66, y: rink.minY + rink.height * 0.15), 80 * s,
            SeatPalette.cyan, s: s, in: &context)
        let puckAt = CGPoint(x: size.width * 0.58, y: rink.minY + rink.height * 0.36)
        streakingPuck(
            at: puckAt, radius: 76 * s, from: CGPoint(x: puckAt.x - 130 * s, y: puckAt.y + 280 * s),
            s: s, in: &context)
    }

    /// Just the table and the shot: no mallets, one puck crossing the ring on
    /// a long burn from the magenta end.
    private func drawMinimal(_ context: inout GraphicsContext, size: CGSize, s: CGFloat) {
        let puckAt = CGPoint(x: size.width * 0.58, y: size.height * 0.38)
        streakingPuck(
            at: puckAt, radius: 70 * s, from: CGPoint(x: puckAt.x - 240 * s, y: puckAt.y + 330 * s),
            s: s, in: &context)
    }

    // MARK: - Shared pieces

    private func goal(
        y: CGFloat, color: Color, size: CGSize, s: CGFloat, in context: inout GraphicsContext
    ) {
        let goalW = 300.0 * s
        var bar = Path()
        bar.move(to: CGPoint(x: size.width / 2 - goalW / 2, y: y))
        bar.addLine(to: CGPoint(x: size.width / 2 + goalW / 2, y: y))
        glowStroke(bar, color: color, width: 18 * s, blur: 22 * s, in: &context)
    }

    /// The white-hot puck with its motion streak trailing back to `from`.
    private func streakingPuck(
        at puckAt: CGPoint, radius: CGFloat, from: CGPoint, s: CGFloat,
        in context: inout GraphicsContext
    ) {
        var streak = Path()
        streak.move(to: puckAt)
        streak.addLine(to: from)
        var haze = context
        haze.addFilter(.blur(radius: 40 * s))
        haze.stroke(
            streak, with: .color(RinkRenderer.puck.opacity(0.4)),
            style: StrokeStyle(lineWidth: radius * 1.2, lineCap: .round))
        glowDisc(puckAt, radius, RinkRenderer.puck, blur: 28 * s, in: &context)
        // The specular glint, up-left like every light in the cabinet.
        context.fill(
            disc(
                CGPoint(x: puckAt.x - radius * 0.36, y: puckAt.y - radius * 0.36),
                radius * 0.26),
            with: .color(.white))
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
