import Foundation

/// The puck's silhouette. A circle is the classic; polygons (a square, a
/// triangle) bounce and tumble differently — corners deflect at steep angles
/// and off-centre hits impart spin.
///
/// A polygon is stored as unit-scale vertices in the puck's own frame, in a
/// FIXED order — collision iterates them in that order so tie-breaking between
/// equidistant vertices is deterministic, never a float coin-flip.
public enum PuckShape: Equatable, Codable, Sendable {
    case circle
    case polygon(vertices: [Vec2])

    /// A square whose corners reach `radius` from the centre.
    public static let square = PuckShape.regular(sides: 4, cornerRadius: 1)
    /// An upward-pointing triangle whose corners reach `radius`.
    public static let triangle = PuckShape.regular(sides: 3, cornerRadius: 1)

    /// A regular `sides`-gon, first vertex pointing up (−y), corners at
    /// `cornerRadius` in unit space (scaled by the puck's radius at use).
    static func regular(sides: Int, cornerRadius: Double) -> PuckShape {
        let vertices = (0..<sides).map { i -> Vec2 in
            let a = -.pi / 2 + 2 * .pi * Double(i) / Double(sides)
            return Vec2(cos(a), sin(a)) * cornerRadius
        }
        return .polygon(vertices: vertices)
    }

    /// The shape's vertices in WORLD space for a puck at `position`, rotated by
    /// `angle`, scaled by `radius`. Empty for a circle.
    public func worldVertices(position: Vec2, angle: Double, radius: Double) -> [Vec2] {
        switch self {
        case .circle:
            return []
        case .polygon(let vertices):
            return vertices.map { position + ($0 * radius).rotated(by: angle) }
        }
    }

    /// The rotational inertia factor `I / (m · r²)` for a unit-mass, unit-radius
    /// shape — how much a given torque spins it. A solid disc is 1/2; a square
    /// about its centre is 1/3 of its half-diagonal² … we keep it simple and
    /// deterministic with a per-shape constant that reads well in play, not a
    /// physically exact integral.
}
