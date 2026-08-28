import Foundation

/// Rink's physics: mallets moving and striking, the puck integrating,
/// bouncing off walls, spinning, being freed when pinned. Split from the
/// flow half (phase, scoring, serve) in Rink.swift; both operate on the same
/// struct, so these are extension methods over its (module-internal) state.
extension Rink {
    /// The mallet goes where the hand says, clamped to its half, and is swept
    /// along its path in steps no longer than the puck's radius — so a fast
    /// hand can't pass through the puck between two positions.
    ///
    /// During a faceoff the puck's force field is closed: the mallet is also
    /// clamped OUT of the bubble, and a finger driven into the bubble leaves the
    /// mallet stranded at the rim rather than warping it to the puck's edge — so
    /// nobody can ride a finger onto the puck the instant the field drops.
    mutating func moveMallet(of player: PlayerID, by drag: Vec2, strikes: Bool) {
        let seat = lineup.seat(of: player)
        let from = mallets[player.rawValue].position
        var to = table.malletZone(for: seat).clamping(from + drag)
        if isFaceoff {
            to = clampedOutOfBubble(to, seat: seat)
        }
        let velocity = (to - from) * (1 / Rink.dt)
        if strikes {
            let steps = max(1, Int(((to - from).length / table.puckRadius).rounded(.up)))
            for step in 1...steps {
                let at = from + (to - from) * (Double(step) / Double(steps))
                collidePuck(withMalletAt: at, velocity: velocity, by: player)
            }
        }
        mallets[player.rawValue] = Mallet(position: to, velocity: velocity)
    }

    /// The nearest point to `p` that keeps the mallet's rim clear of the faceoff
    /// bubble around the puck. A point already inside is pushed back out to the
    /// rim — the mallet stops there, disconnected from the finger.
    private func clampedOutOfBubble(_ p: Vec2, seat: Seat) -> Vec2 {
        let keepOut = table.faceoffBubbleRadius + table.malletRadius
        let offset = p - puck.position
        let distance = offset.length
        guard distance < keepOut else { return p }
        // Push back along the offset; if the mallet is dead on the puck, push it
        // toward the seat's own goal (opposite its inward direction).
        let direction = distance > 0 ? offset * (1 / distance) : -seat.inward
        return puck.position + direction * keepOut
    }

    /// Circle–circle against a kinematic mallet: push the puck clear, and if
    /// they were closing, bounce it off with the mallet's motion added.
    private mutating func collidePuck(
        withMalletAt center: Vec2, velocity malletVelocity: Vec2, by player: PlayerID? = nil
    ) {
        let reach = table.puckRadius + table.malletRadius
        let offset = puck.position - center
        let distance = offset.length
        guard distance < reach else { return }
        let normal = distance > 0 ? offset * (1 / distance) : Vec2(0, -1)
        let clear = pushedClear(of: center, along: normal, reach: reach)
        puck.position = clear.position
        let closing = (puck.velocity - malletVelocity).dot(normal)
        if closing < 0 {
            puck.velocity -= normal * ((1 + table.restitution) * closing)
            if let player {
                events.append(.malletHit(player, speed: -closing))
            }
            // A shaped puck spins when the hit has any sideways bite: the
            // tangential part of the mallet's approach grabs the puck's edge,
            // like putting english on it. A dead-centre square-on hit adds none.
            if case .polygon = table.puckShape {
                let relative = puck.velocity - malletVelocity
                let tangent = normal.perpendicular
                puck.angularVelocity -= relative.dot(tangent) / table.puckRadius * Rink.spinBite
            }
        }
        // Pinned against a wall: kill the speed aimed into it (the wall takes
        // it) and let it slide out ALONG the wall instead, so a hard slam
        // doesn't tunnel back through to the mallet's far side. Freeing a puck
        // that ends up STUCK on the wall is handled in `stepPuck`, once nothing
        // is holding it — a player can't get a mallet between puck and wall, so
        // the sim must peel it off itself.
        if let wall = clear.wall {
            let into = puck.velocity.dot(wall)
            if into > 0 {
                let along = (puck.position - center - wall * (puck.position - center).dot(wall))
                    .normalized
                puck.velocity = puck.velocity - wall * into + along * into
            }
        }
    }

    /// Peel a stuck puck off a wall. A puck resting on a wall with no speed off
    /// it — glued there, or only sliding along — can never be freed by a mallet
    /// (a player can't reach between it and the boards), so the sim does it:
    /// once no mallet is touching the puck, give it a brisk shove inward, enough
    /// to clear its own radius before drag eats it. Called at the end of a tick,
    /// so a mallet actively holding the puck against the wall keeps it there and
    /// it pops free the instant the mallet lifts.
    private mutating func freeStuckPuckFromWall() {
        let field = table.puckField
        var inward = Vec2.zero
        if puck.position.x <= field.minX + 1e-6 { inward.x = 1 }
        if puck.position.x >= field.maxX - 1e-6 { inward.x = -1 }
        // The short walls are open across the mouth — never peel a puck off them
        // there, or one heading into the goal gets shoved back onto the ice.
        if !table.isInGoalMouth(x: puck.position.x) {
            if puck.position.y <= field.minY + 1e-6 { inward.y = 1 }
            if puck.position.y >= field.maxY - 1e-6 { inward.y = -1 }
        }
        guard inward != .zero else { return }
        let escapeSpeed = table.puckRadius * 2
        guard puck.velocity.dot(inward) < escapeSpeed else { return }
        // Held by a mallet still overlapping it? Leave it — it pops free next
        // tick once the mallet moves off.
        let reach = table.puckRadius + table.malletRadius
        if mallets.contains(where: { puck.position.distance(to: $0.position) < reach }) { return }
        puck.position += inward * (table.puckRadius * 0.5)
        puck.velocity += inward * (escapeSpeed - puck.velocity.dot(inward))
        puck.position = field.clamping(puck.position)
    }

    /// Where the puck goes to be clear of a mallet at `center`: straight out
    /// along `normal` — unless that is through a wall. **A puck pinned against
    /// a wall slides along it** until it is clear of the mallet, as a real one
    /// squirts out sideways; `wall` is then that wall's outward normal. Pushing
    /// it through the wall instead let the wall reflection mirror it back to
    /// the mallet's far side, where it left backwards at speed — "the mallet
    /// warped through the puck".
    private func pushedClear(of center: Vec2, along normal: Vec2, reach: Double) -> (
        position: Vec2, wall: Vec2?
    ) {
        let field = table.puckField
        let free = center + normal * reach
        guard !field.contains(free) else { return (free, nil) }
        var target = field.clamping(free)
        let d = target - center
        let wall: Vec2
        if target.x != free.x {
            wall = Vec2(free.x > field.maxX ? 1 : -1, 0)
        } else {
            wall = Vec2(0, free.y > field.maxY ? 1 : -1)
        }
        guard d.lengthSquared < reach * reach else { return (target, wall) }
        // Slide along the wall the clamp hit: solve the other coordinate so the
        // distance is exactly `reach`, keeping the puck on the side it was on.
        if wall.x != 0 {
            let dy = max(0, reach * reach - d.x * d.x).squareRoot()
            target.y = center.y + (d.y >= 0 ? dy : -dy)
        } else {
            let dx = max(0, reach * reach - d.y * d.y).squareRoot()
            target.x = center.x + (d.x >= 0 ? dx : -dx)
        }
        // In a corner the slide may hit the other wall too; inside beats clear.
        return (field.clamping(target), wall)
    }

    mutating func stepPuck() {
        var v = puck.velocity
        let speed = v.length
        if speed > table.maxSpeed {
            v *= table.maxSpeed / speed
        }
        v *= exp(-table.drag * Rink.dt)
        if v.length < table.restSpeed {
            v = .zero
        }
        // Angular motion decays like linear, and stops below a small rest rate.
        var omega = puck.angularVelocity * exp(-table.drag * Rink.dt)
        if abs(omega) < Rink.restAngularVelocity {
            omega = 0
        }
        let p = puck.position + v * Rink.dt
        let newAngle = puck.angle + omega * Rink.dt

        // A goal counts only once the WHOLE puck is past the line and lined up
        // with the mouth — so it flies all the way in before warping back, not
        // the instant its nose touches the line.
        if p.y <= table.topGoalLine, table.isInGoalMouth(x: p.x) {
            goal(against: .top)
            return
        }
        if p.y >= table.bottomGoalLine, table.isInGoalMouth(x: p.x) {
            goal(against: .bottom)
            return
        }

        puck = Puck(position: p, velocity: v, angle: newAngle, angularVelocity: omega)
        switch table.puckShape {
        case .circle: bounceCircleOffWalls()
        case .polygon: bouncePolygonOffWalls()
        }

        // The puck may have moved into a resting mallet.
        for mallet in mallets {
            collidePuck(withMalletAt: mallet.position, velocity: mallet.velocity)
        }
        // …and if it ended the tick stuck against a wall with nothing holding
        // it, peel it off — a mallet can never reach between puck and boards.
        freeStuckPuckFromWall()
    }

    /// A circle bounces off each wall by mirroring the position back inside and
    /// the velocity component with it, keeping `restitution` of it. (Goal
    /// crossings were already handled in `stepPuck`.)
    private mutating func bounceCircleOffWalls() {
        let field = table.puckField
        var p = puck.position
        var v = puck.velocity
        // The short walls are open across the mouth — a puck lined up with the
        // goal passes through (to be scored once fully in) instead of bouncing.
        let openMouth = table.isInGoalMouth(x: p.x)
        if p.y < field.minY, !openMouth {
            p.y = field.minY + (field.minY - p.y)
            events.append(.wallBounce(speed: abs(v.y)))
            v.y = -v.y * table.restitution
        } else if p.y > field.maxY, !openMouth {
            p.y = field.maxY - (p.y - field.maxY)
            events.append(.wallBounce(speed: abs(v.y)))
            v.y = -v.y * table.restitution
        }
        if p.x < field.minX {
            p.x = field.minX + (field.minX - p.x)
            events.append(.wallBounce(speed: abs(v.x)))
            v.x = -v.x * table.restitution
        } else if p.x > field.maxX {
            p.x = field.maxX - (p.x - field.maxX)
            events.append(.wallBounce(speed: abs(v.x)))
            v.x = -v.x * table.restitution
        }
        // Clamp X to the field always, but Y only when the mouth is closed —
        // else a puck flying into the goal is dragged back onto the ice.
        p.x = min(max(p.x, field.minX), field.maxX)
        if !openMouth {
            p.y = min(max(p.y, field.minY), field.maxY)
        }
        puck.position = p
        puck.velocity = v
    }

    /// A polygon bounces off its deepest-penetrating corner against each wall in
    /// turn — a rigid impulse that both reflects and spins it. Walls are visited
    /// in a fixed order so a corner-in-corner resolves deterministically.
    private mutating func bouncePolygonOffWalls() {
        let field = table.puckField
        // The short walls (first two) are open across the mouth — a puck lined
        // up with the goal passes through instead of bouncing off the boards.
        let openMouth = table.isInGoalMouth(x: puck.position.x)
        var walls: [PolygonCollision.Wall] = [
            .init(normal: Vec2(-1, 0), limit: -field.minX),
            .init(normal: Vec2(1, 0), limit: field.maxX),
        ]
        if !openMouth {
            walls.append(.init(normal: Vec2(0, -1), limit: -field.minY))
            walls.append(.init(normal: Vec2(0, 1), limit: field.maxY))
        }
        for wall in walls {
            let body = PolygonCollision.Body(
                shape: table.puckShape, center: puck.position, angle: puck.angle,
                radius: table.puckRadius, velocity: puck.velocity,
                angularVelocity: puck.angularVelocity)
            guard
                let result = PolygonCollision.resolve(
                    body, wall: wall, restitution: table.restitution)
            else { continue }
            puck.position += result.positionShift
            puck.velocity = result.velocity
            puck.angularVelocity = result.angularVelocity
            if result.impactSpeed > 0 {
                events.append(.wallBounce(speed: result.impactSpeed))
            }
        }
    }
}
