import Foundation

/// Deterministic collision of a polygon puck against an axis-aligned wall.
///
/// A polygon hits a wall at its deepest-penetrating VERTEX (vertices tested in
/// fixed index order, ties broken by that order — never a float coin-flip, so
/// the same state always resolves the same way).
///
/// **A spinning corner STEERS the bounce, it doesn't launch it.** With no spin
/// a shaped puck bounces like a disc — reflected off the wall normal. When it
/// IS spinning, the corner grabs the boards and skews the outgoing direction
/// off-axis (which way depends on the spin's sign), spending some spin to do
/// it. The bounce keeps the puck's speed (restitution only), so a spinning
/// puck never rockets off the wall — the spin turns the path, it doesn't add
/// momentum, and the spin resists dropping to zero rather than dumping at once.
enum PolygonCollision {
    /// Radians the outgoing velocity is steered per (rad/s of spin) × (corner
    /// offset along the wall, in radii). A feel dial for how wild the deflection
    /// gets; 0 makes a shaped puck bounce exactly like a disc.
    static let steerPerSpin = 0.03
    /// Fraction of the steer's spin the bounce spends (the rest carries on).
    static let spinSpent = 0.35

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

    /// A polygon puck's state at collision time.
    struct Body {
        var shape: PuckShape
        var center: Vec2
        var angle: Double
        var radius: Double
        var velocity: Vec2
        var angularVelocity: Double
    }

    /// Resolve `body` against one `wall`, or nil if it isn't penetrating.
    static func resolve(_ body: Body, wall: Wall, restitution: Double) -> Result? {
        let vertices = body.shape.worldVertices(
            position: body.center, angle: body.angle, radius: body.radius)
        guard !vertices.isEmpty else { return nil }

        var contact: (point: Vec2, depth: Double)?
        for vertex in vertices {
            let signed = vertex.dot(wall.normal) - wall.limit  // > 0 = outside the field
            if signed > (contact?.depth ?? 0) {
                contact = (vertex, signed)
            }
        }
        guard let contact else { return nil }

        let positionShift = wall.normal * -contact.depth
        let closing = body.velocity.dot(wall.normal)  // the puck's own approach
        guard closing > 0 else {
            // The centre is not heading into the wall — a glancing corner touch.
            // Unpenetrate only.
            return Result(
                velocity: body.velocity, angularVelocity: body.angularVelocity,
                positionShift: positionShift, impactSpeed: 0)
        }

        // Disc-like reflection: mirror the wall-normal component, keep speed.
        var outgoing = body.velocity - wall.normal * ((1 + restitution) * closing)

        // Spin steers it: rotate the outgoing vector by an angle set by the spin
        // and how far along the wall the corner sits (its lever). Sign from the
        // spin, so opposite spins veer opposite ways.
        let arm = contact.point - body.center
        let lever = arm.dot(wall.normal.perpendicular) / body.radius
        let steer = body.angularVelocity * lever * steerPerSpin
        outgoing = outgoing.rotated(by: steer)

        // Spending some spin to steer — it bleeds, it doesn't dump.
        let angularVelocity = body.angularVelocity * (1 - spinSpent * abs(lever))

        return Result(
            velocity: outgoing, angularVelocity: angularVelocity,
            positionShift: positionShift, impactSpeed: closing)
    }
}
