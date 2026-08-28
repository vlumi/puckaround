import Foundation

/// 2D vector over `Double`. The sim's only geometry currency — everything
/// deterministic flows through these few operations.
public struct Vec2: Equatable, Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(0, 0)

    /// Unit vector at `angle` radians: 0 = +x, and a positive angle turns toward
    /// +y — which is DOWN on screen, since world space is y-down (see `Playfield`).
    public init(angle: Double) {
        self.init(cos(angle), sin(angle))
    }

    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    public static func * (a: Vec2, s: Double) -> Vec2 { Vec2(a.x * s, a.y * s) }
    public static prefix func - (a: Vec2) -> Vec2 { Vec2(-a.x, -a.y) }
    public static func += (a: inout Vec2, b: Vec2) { a = a + b }
    public static func -= (a: inout Vec2, b: Vec2) { a = a - b }
    public static func *= (a: inout Vec2, s: Double) { a = a * s }

    public func dot(_ other: Vec2) -> Double { x * other.x + y * other.y }

    public var length: Double { (x * x + y * y).squareRoot() }
    public var lengthSquared: Double { x * x + y * y }

    /// Normalized copy; `.zero` stays `.zero` rather than dividing by zero.
    public var normalized: Vec2 {
        let len = length
        return len > 0 ? Vec2(x / len, y / len) : .zero
    }

    public func distance(to other: Vec2) -> Double { (self - other).length }

    /// z of the 2D cross product — the signed area, and the lever arm used for
    /// torque (`r.cross(impulse)`).
    public func cross(_ other: Vec2) -> Double { x * other.y - y * other.x }

    /// Rotated by `angle` radians about the origin.
    public func rotated(by angle: Double) -> Vec2 {
        let c = cos(angle)
        let s = sin(angle)
        return Vec2(x * c - y * s, x * s + y * c)
    }

    /// Rotated 90° left — a normal to this vector.
    public var perpendicular: Vec2 { Vec2(-y, x) }

    /// Closest point to `self` on segment `a`–`b`.
    public func closestPoint(onSegment a: Vec2, _ b: Vec2) -> Vec2 {
        let ab = b - a
        let denominator = ab.lengthSquared
        guard denominator > 0 else { return a }
        let t = max(0, min(1, (self - a).dot(ab) / denominator))
        return a + ab * t
    }

    /// Distance from `self` to segment `a`–`b`.
    public func distance(toSegment a: Vec2, _ b: Vec2) -> Double {
        distance(to: closestPoint(onSegment: a, b))
    }
}
