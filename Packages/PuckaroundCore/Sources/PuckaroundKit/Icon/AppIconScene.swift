import PuckaroundCore
import SwiftUI

/// The app icon, drawn by the game's own recipe — a puck skating across the
/// ice toward a seat's band, its trail behind it. No image assets: `make icon`
/// renders this at 1024×1024 into the asset catalog.
public struct AppIconScene: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            let s = size.width / 1024  // designed at 1024
            let full = CGRect(origin: .zero, size: size)

            // Ground, then the ice filling the icon with a soft margin.
            context.fill(Path(full), with: .color(RinkRenderer.ground))
            let ice = full.insetBy(dx: 96 * s, dy: 96 * s)
            let iceShape = Path(roundedRect: ice, cornerRadius: 72 * s)
            context.fill(iceShape, with: .color(RinkRenderer.ice))

            // Four seat bands — the table is for everyone around it.
            context.drawLayer { layer in
                layer.clip(to: iceShape)
                let depth = 92 * s
                let bands: [(CGRect, Color)] = [
                    (
                        CGRect(x: ice.minX, y: ice.maxY - depth, width: ice.width, height: depth),
                        SeatPalette.colors[0]
                    ),
                    (
                        CGRect(x: ice.minX, y: ice.minY, width: ice.width, height: depth),
                        SeatPalette.colors[1]
                    ),
                    (
                        CGRect(x: ice.minX, y: ice.minY, width: depth, height: ice.height),
                        SeatPalette.colors[2]
                    ),
                    (
                        CGRect(x: ice.maxX - depth, y: ice.minY, width: depth, height: ice.height),
                        SeatPalette.colors[3]
                    ),
                ]
                for (band, color) in bands {
                    layer.fill(Path(band), with: .color(color.opacity(0.55)))
                }
            }

            // Centre ring.
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let ring = 150 * s
            context.stroke(
                Path(
                    ellipseIn: CGRect(
                        x: centre.x - ring, y: centre.y - ring, width: 2 * ring, height: 2 * ring)),
                with: .color(RinkRenderer.lines), lineWidth: 10 * s)

            // The puck, mid-flight from bottom-left toward top-right, trailing
            // a fading streak of where it has been.
            let puckAt = CGPoint(x: 640 * s, y: 380 * s)
            let from = CGPoint(x: 300 * s, y: 720 * s)
            let steps = 6
            for i in 0..<steps {
                let t = Double(i) / Double(steps)
                let p = CGPoint(
                    x: from.x + (puckAt.x - from.x) * t, y: from.y + (puckAt.y - from.y) * t)
                let r = (60 + 40 * t) * s
                context.fill(
                    Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
                    with: .color(RinkRenderer.puck.opacity(0.10 + 0.12 * t)))
            }
            let r = 110 * s
            context.fill(
                Path(
                    ellipseIn: CGRect(x: puckAt.x - r, y: puckAt.y - r, width: 2 * r, height: 2 * r)
                ),
                with: .color(RinkRenderer.puck))
            let h = 44 * s
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: puckAt.x - 50 * s - h / 2, y: puckAt.y - 50 * s - h / 2, width: h,
                        height: h)),
                with: .color(Color.white.opacity(0.28)))
        }
    }
}
