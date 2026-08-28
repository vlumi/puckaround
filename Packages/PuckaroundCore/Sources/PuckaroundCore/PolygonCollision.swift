import Foundation

/// Deterministic collision of a rigid polygon puck against an axis-aligned wall.
///
/// A polygon hits a wall at its deepest-penetrating VERTEX. Vertices are tested
/// in fixed index order and ties broken by that order (never a float coin-flip),
/// so the same state always resolves the same way — the sim's determinism
/// contract. The response is a rigid-body impulse: it reflects the contact
/// point's velocity (linear + rotational) about the wall normal, which both
/// bounces the puck and spins it when the hit is off-centre.
enum PolygonCollision {
    struct Result: Equatable {
        var velocity: Vec2
        var angularVelocity: Double
        /// How far the puck was pushed to sit clear of the wall.
        var positionShift: Vec2
        /// The impact speed into the wall, for the bounce event.
        var impactSpeed: Double
    }

    /// The four table walls as (outward normal, the world coordinate of the
    /// wall plane along that normal's axis).
    struct Wall {
        var normal: Vec2  // points OUT of the field
        var limit: Double  // the field-edge coordinate on the normal's axis
    }

    /// A polygon puck's full rigid-body state at collision time.
    struct Body {
        var shape: PuckShape
        var center: Vec2
        var angle: Double
        var radius: Double
        var velocity: Vec2
        var angularVelocity: Double
        /// `I / (m·r²)` — how much torque spins it.
        var inertiaFactor: Double
    }

    /// Resolve `body` against one `wall`, or nil if it isn't penetrating.
    /// `restitution` scales the bounce.
    static func resolve(_ body: Body, wall: Wall, restitution: Double) -> Result? {
        let center = body.center
        let radius = body.radius
        let velocity = body.velocity
        let angularVelocity = body.angularVelocity
        let inertiaFactor = body.inertiaFactor
        let vertices = body.shape.worldVertices(
            position: center, angle: body.angle, radius: radius)
        guard !vertices.isEmpty else { return nil }

        // The deepest penetration past the wall plane, at the first such vertex
        // in index order (deterministic tie-break).
        var contact: (point: Vec2, depth: Double)?
        for vertex in vertices {
            let signed = vertex.dot(wall.normal) - wall.limit  // > 0 = outside the field
            if signed > (contact?.depth ?? 0) {
                contact = (vertex, signed)
            }
        }
        guard let contact else { return nil }

        // Contact-point velocity: linear plus the rotational term ω × r.
        let arm = contact.point - center
        let pointVelocity = velocity + arm.perpendicular * angularVelocity
        let closing = pointVelocity.dot(wall.normal)  // > 0 = moving into the wall
        // Push the vertex back to the wall plane along the normal.
        let positionShift = wall.normal * -contact.depth
        guard closing > 0 else {
            // Grazing / separating: just unpenetrate, no bounce.
            return Result(
                velocity: velocity, angularVelocity: angularVelocity,
                positionShift: positionShift, impactSpeed: 0)
        }

        // Rigid impulse along the normal. Effective mass includes the lever arm
        // through the inertia factor (unit mass, so m = 1; I = inertiaFactor·r²).
        let armCrossNormal = arm.cross(wall.normal)
        let inertia = inertiaFactor * radius * radius
        let denominator = 1 + (armCrossNormal * armCrossNormal) / inertia
        let impulse = -(1 + restitution) * closing / denominator

        return Result(
            velocity: velocity + wall.normal * impulse,
            angularVelocity: angularVelocity + armCrossNormal * impulse / inertia,
            positionShift: positionShift,
            impactSpeed: closing)
    }
}
