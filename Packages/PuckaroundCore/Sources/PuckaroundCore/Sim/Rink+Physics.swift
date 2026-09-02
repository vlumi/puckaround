import Foundation

/// Rink's physics: mallets moving and striking, each puck integrating, bouncing
/// off walls, posts and each other, spinning, and being freed when pinned. The
/// flow half (phase, scoring, serve) lives in Rink.swift; both extend the same
/// struct. Everything resolves in fixed index order, so the chaos of a
/// multi-puck table stays deterministic.
extension Rink {
    /// Moves a mallet to where the hand asks — clamped to its zone, out of the
    /// faceoff bubble, and swept in puck-radius steps so a fast hand can't tunnel
    /// through a puck. A `grab` snaps it under the finger first (placing the
    /// hand, not swinging), so the grab tick itself never strikes.
    mutating func moveMallet(at index: Int, grabTo grab: Vec2? = nil, by drag: Vec2, strikes: Bool)
    {
        let slot = slots[index]
        let zone = table.malletZone(for: slot)
        let from = grab.map(zone.clamping) ?? mallets[index].position
        var to = zone.clamping(from + drag)
        if isFaceoff {
            to = clampedOutOfBubble(to, side: slot.side)
        }
        let velocity = (to - from) * (1 / Rink.dt)
        if strikes {
            let steps = max(1, Int(((to - from).length / table.puckRadius).rounded(.up)))
            for step in 1...steps {
                let at = from + (to - from) * (Double(step) / Double(steps))
                for puckIndex in pucks.indices {
                    collide(puckAt: puckIndex, withMalletAt: at, velocity: velocity, by: slot)
                }
            }
        }
        mallets[index] = Mallet(position: to, velocity: velocity)
    }

    /// Keeps a point clear of the faceoff force field around the parked pucks:
    /// a point inside the keep-out radius is pushed back to its rim, disconnected
    /// from the finger, so nobody can ride onto a puck the instant the field
    /// drops. The field is centered on the table — where the faceoff row sits.
    private func clampedOutOfBubble(_ p: Vec2, side: Side) -> Vec2 {
        let keepOut = table.faceoffBubbleRadius + table.malletRadius
        let offset = p - table.center
        guard offset.length < keepOut else { return p }
        let direction = offset.length > 0 ? offset.normalized : -side.inward
        return table.center + direction * keepOut
    }

    /// Circle–circle against a kinematic mallet: push the puck clear, and if they
    /// were closing, bounce it off with the mallet's motion and english added.
    private mutating func collide(
        puckAt index: Int, withMalletAt center: Vec2, velocity malletVelocity: Vec2,
        by slot: MalletSlot? = nil
    ) {
        let reach = table.puckRadius + table.malletRadius
        let mallet = malletSeenAcrossSeam(by: pucks[index].position, from: center)
        let offset = pucks[index].position - mallet
        guard offset.length < reach else { return }
        let normal = offset.length > 0 ? offset.normalized : Vec2(0, -1)
        let clear = pushedClear(of: mallet, along: normal, reach: reach)
        pucks[index].position = clear.position

        let closing = (pucks[index].velocity - malletVelocity).dot(normal)
        if closing < 0 {
            pucks[index].velocity -= normal * ((1 + table.restitution) * closing)
            if let slot { events.append(.malletHit(slot, speed: -closing)) }
            let tangential = (pucks[index].velocity - malletVelocity).dot(normal.perpendicular)
            pucks[index].angularVelocity -=
                tangential / table.puckRadius * spinBite(for: pucks[index].shape)
        }
        if let wall = clear.wall { slideAlongWall(puckAt: index, wall: wall, from: mallet) }
    }

    /// A puck pinned between the mallet and a wall squirts out ALONG the wall
    /// instead of tunneling back through the mallet — the "mallet warped through
    /// the puck" bug. Redirects the into-wall speed sideways, along the wall.
    private mutating func slideAlongWall(puckAt index: Int, wall: Vec2, from center: Vec2) {
        let into = pucks[index].velocity.dot(wall)
        guard into > 0 else { return }
        let speed = pucks[index].velocity.length
        let offset = pucks[index].position - center
        let along = (offset - wall * offset.dot(wall)).normalized
        pucks[index].velocity += along * into - wall * into
        // A redirection, never a boost: a diagonal pin used to leave the puck
        // up to √2× faster than it arrived, punching past the speed cap.
        let after = pucks[index].velocity.length
        if after > speed, after > 0 {
            pucks[index].velocity *= speed / after
        }
    }

    /// The mallet as a puck sees it: its own place, or — on a wrap table — its
    /// image a table-width over when that is nearer, so a mallet at one side edge
    /// can strike a puck at the other.
    private func malletSeenAcrossSeam(by puckPosition: Vec2, from center: Vec2) -> Vec2 {
        guard table.sideWalls == .wrap else { return center }
        let dx = puckPosition.x - center.x
        if dx > table.size.x / 2 { return center + Vec2(table.size.x, 0) }
        if dx < -table.size.x / 2 { return center - Vec2(table.size.x, 0) }
        return center
    }

    /// Peels a puck left resting against a wall off it — no mallet can reach
    /// between a puck and the boards, so the sim frees it once nothing holds it.
    /// The side walls only trap on a solid table; the goal openings never trap.
    private mutating func freeStuckPuckFromWall(at index: Int) {
        let field = table.puckField
        let position = pucks[index].position
        var inward = Vec2.zero
        if table.sideWalls == .solid {
            if field.isAtLeftEdge(position) { inward.x = 1 }
            if field.isAtRightEdge(position) { inward.x = -1 }
        }
        if field.isAtTopEdge(position), !table.goal(.top).admitsOpening(position.x) {
            inward.y = 1
        }
        if field.isAtBottomEdge(position), !table.goal(.bottom).admitsOpening(position.x) {
            inward.y = -1
        }
        guard inward != .zero else { return }

        let escapeSpeed = table.puckRadius * 2
        guard pucks[index].velocity.dot(inward) < escapeSpeed else { return }
        let reach = table.puckRadius + table.malletRadius
        guard !mallets.contains(where: { position.distance(to: $0.position) < reach }) else {
            return  // still held; it pops free the tick the mallet lifts
        }
        pucks[index].position += inward * (table.puckRadius * 0.5)
        pucks[index].velocity +=
            inward * (escapeSpeed - pucks[index].velocity.dot(inward))
        pucks[index].position = field.clamping(pucks[index].position)
    }

    /// Where a puck goes to sit clear of a mallet: straight out along `normal`,
    /// unless that crosses a wall — then it slides along the wall (returned as its
    /// outward normal) to stay clear without tunneling through it. A wrap table's
    /// side walls don't confine, so only the goal walls bound x there.
    private func pushedClear(of center: Vec2, along normal: Vec2, reach: Double) -> (
        position: Vec2, wall: Vec2?
    ) {
        var field = table.puckField
        if table.sideWalls == .wrap {
            field = Rect(
                x: field.minX - table.size.x, y: field.minY,
                width: field.width + 2 * table.size.x, height: field.height)
        }
        let free = center + normal * reach
        guard !field.contains(free) else { return (free, nil) }

        var target = field.clamping(free)
        let d = target - center
        let wall =
            target.x != free.x
            ? Vec2(free.x > field.maxX ? 1 : -1, 0)
            : Vec2(0, free.y > field.maxY ? 1 : -1)
        guard d.lengthSquared < reach * reach else { return (target, wall) }
        // Slide: solve the free coordinate so the distance is exactly `reach`.
        if wall.x != 0 {
            target.y =
                center.y + (d.y >= 0 ? 1 : -1) * (reach * reach - d.x * d.x).squareRootClamped
        } else {
            target.x =
                center.x + (d.x >= 0 ? 1 : -1) * (reach * reach - d.y * d.y).squareRootClamped
        }
        return (field.clamping(target), wall)
    }

    /// One tick of puck motion: each puck steps in index order (stopping cold if
    /// a goal ends the game), then the pucks resolve against each other.
    mutating func stepPucks() {
        for index in pucks.indices {
            guard !step(puckAt: index) else { return }
        }
        collidePuckPairs()
    }

    /// One puck's step: integrate with drag and a speed cap, score if it crosses
    /// a goal line cleanly (returning whether that ended the game), else bounce
    /// off walls/posts, wrap the sides, re-touch any mallet it moved into, and
    /// peel it off a wall if it stuck.
    private mutating func step(puckAt index: Int) -> Bool {
        let puck = pucks[index]
        var v = puck.velocity
        // Pace lifts the cap and thins the surface — a later lap plays faster
        // and the ice stays slick longer. 1 everywhere but staged tables.
        let cap = table.maxSpeed * pace
        let drag = table.drag / pace
        let friction = table.friction / pace
        if v.length > cap { v *= cap / v.length }
        // Exponential drag carries the shot; the flat friction floor kills
        // the slow tail — fast pucks fly, crawls settle in a beat.
        let slowed = max(0, v.length * exp(-drag * Rink.dt) - friction * Rink.dt)
        v = slowed >= table.restSpeed && v.length > 0 ? v.normalized * slowed : .zero
        var omega = puck.angularVelocity * exp(-drag * Rink.dt)
        if abs(omega) < Rink.restAngularVelocity { omega = 0 }
        let p = puck.position + v * Rink.dt

        for side in Side.allCases where scores(p, into: side) {
            return goal(against: side, puckAt: index)
        }

        pucks[index] = Puck(
            position: p, velocity: v, angle: puck.angle + omega * Rink.dt,
            angularVelocity: omega, shape: puck.shape)
        switch puck.shape {
        case .circle: bounceCircleOffWalls(at: index)
        case .polygon: bouncePolygonOffWalls(at: index)
        }
        wrapSideWalls(at: index)
        for mallet in mallets {
            collide(puckAt: index, withMalletAt: mallet.position, velocity: mallet.velocity)
        }
        collideBumpers(puckAt: index)
        collideBricks(puckAt: index)
        freeStuckPuckFromWall(at: index)
        rescueDeadPuck(at: index)
        return false
    }

    /// Pucks bounce off each other as equal-mass discs — shaped pucks included,
    /// approximated by their bounding circle, which reads fine at speed. Pairs
    /// resolve in fixed index order, so the mayhem stays deterministic.
    private mutating func collidePuckPairs() {
        guard pucks.count > 1 else { return }
        let reach = table.puckRadius * 2
        for i in pucks.indices {
            for j in pucks.indices where j > i {
                let offset = pucks[j].position - pucks[i].position
                let distance = offset.length
                guard distance < reach else { continue }
                let normal = distance > 0 ? offset.normalized : Vec2(0, -1)
                let overlap = reach - distance
                pucks[i].position -= normal * (overlap / 2)
                pucks[j].position += normal * (overlap / 2)
                let closing = (pucks[i].velocity - pucks[j].velocity).dot(normal)
                guard closing > 0 else { continue }
                // Equal masses: the closing speed splits between them, keeping
                // the table's restitution — a clack, not a magnet.
                let impulse = normal * (closing * (1 + table.restitution) / 2)
                pucks[i].velocity -= impulse
                pucks[j].velocity += impulse
                events.append(.puckHit(speed: closing))
            }
        }
    }

    /// Whether a puck center at `p` has crossed `side`'s goal line fully and
    /// lined up with the scoring mouth — a goal.
    private func scores(_ p: Vec2, into side: Side) -> Bool {
        let goal = table.goal(side)
        return goal.isPast(p.y) && goal.admitsMouth(p.x)
    }

    /// On a wrap table a puck whose center has fully left one long side re-enters
    /// the opposite side at the same height, keeping its velocity. A no-op on a
    /// solid table, and never while the puck is in a goal recess.
    private mutating func wrapSideWalls(at index: Int) {
        let position = pucks[index].position
        guard table.sideWalls == .wrap, goalRecess(position) == nil else { return }
        if position.x < 0 {
            pucks[index].position.x += table.size.x
        } else if position.x > table.size.x {
            pucks[index].position.x -= table.size.x
        }
    }

    /// The goal a puck at `p` has entered (center past a short wall, within that
    /// side's opening), or nil on the open field.
    private func goalRecess(_ p: Vec2) -> Goal? {
        let field = table.puckField
        if p.y < field.minY, table.goal(.top).admitsOpening(p.x) { return table.goal(.top) }
        if p.y > field.maxY, table.goal(.bottom).admitsOpening(p.x) { return table.goal(.bottom) }
        return nil
    }

    /// A circle mirrors off each wall (position and velocity), then its spin
    /// steers the outgoing angle a little and the wall bleeds some of it. Goal
    /// crossings were already scored in `step(puckAt:)`.
    private mutating func bounceCircleOffWalls(at index: Int) {
        var p = pucks[index].position
        var v = pucks[index].velocity
        let shortHit = bounceShortWalls(&p, &v)
        let xHit = bounceXWalls(&p, &v)
        let bounced = shortHit || xHit
        if bounced, pucks[index].angularVelocity != 0 {
            v = v.rotated(by: pucks[index].angularVelocity * Rink.discSteerPerSpin)
            pucks[index].angularVelocity *= Rink.discSpinKeptOnBounce
        }
        clampToBounds(&p)
        pucks[index].position = p
        pucks[index].velocity = v
    }

    /// Reflects the puck off whichever short (goal-end) wall it crossed — but not
    /// across the goal opening, which lets it through to score. The wall bounce
    /// event carries the incoming speed.
    private mutating func bounceShortWalls(_ p: inout Vec2, _ v: inout Vec2) -> Bool {
        let field = table.puckField
        if p.y < field.minY, !table.goal(.top).admitsOpening(p.x) {
            events.append(.wallBounce(speed: abs(v.y)))
            reflect(&p.y, &v.y, off: field.minY, from: .below)
        } else if p.y > field.maxY, !table.goal(.bottom).admitsOpening(p.x) {
            events.append(.wallBounce(speed: abs(v.y)))
            reflect(&p.y, &v.y, off: field.maxY, from: .above)
        } else {
            return false
        }
        return true
    }

    /// Reflects the puck off its x-wall: a goal post inside an opening (keeping it
    /// in the goal, no bounce event), or a solid side wall on the open field.
    private mutating func bounceXWalls(_ p: inout Vec2, _ v: inout Vec2) -> Bool {
        if let goal = goalRecess(p), !goal.admitsMouth(p.x) {
            if p.x < goal.postLeft {
                reflect(&p.x, &v.x, off: goal.postLeft, from: .below)
            } else if p.x > goal.postRight {
                reflect(&p.x, &v.x, off: goal.postRight, from: .above)
            }
            return true
        }
        guard goalRecess(p) == nil, table.sideWalls == .solid else { return false }
        let field = table.puckField
        if p.x < field.minX {
            events.append(.wallBounce(speed: abs(v.x)))
            reflect(&p.x, &v.x, off: field.minX, from: .below)
        } else if p.x > field.maxX {
            events.append(.wallBounce(speed: abs(v.x)))
            reflect(&p.x, &v.x, off: field.maxX, from: .above)
        } else {
            return false
        }
        return true
    }

    private enum Approach { case below, above }

    /// Mirrors one coordinate back inside `edge` and reverses its velocity,
    /// keeping `restitution` of it.
    private func reflect(
        _ coord: inout Double, _ vel: inout Double, off edge: Double, from side: Approach
    ) {
        coord = side == .below ? edge + (edge - coord) : edge - (coord - edge)
        vel = -vel * table.restitution
    }

    /// Confines a puck's center: to the mouth's posts inside a goal recess, to
    /// the field on a solid table, and — off a goal opening — to the field in y.
    private mutating func clampToBounds(_ p: inout Vec2) {
        let field = table.puckField
        if let goal = goalRecess(p) {
            p.x = min(max(p.x, goal.postLeft), goal.postRight)
        } else if table.sideWalls == .solid {
            p.x = min(max(p.x, field.minX), field.maxX)
        }
        if goalRecess(p) == nil {
            p.y = min(max(p.y, field.minY), field.maxY)
        }
    }

    /// A polygon resolves against each active wall in a fixed order (deterministic
    /// tie-break), taking a rigid impulse that both reflects and spins it.
    private mutating func bouncePolygonOffWalls(at index: Int) {
        for wall in activeWalls(for: pucks[index].position) {
            let puck = pucks[index]
            let body = PolygonCollision.Body(
                shape: puck.shape, center: puck.position, angle: puck.angle,
                radius: table.puckRadius, velocity: puck.velocity,
                angularVelocity: puck.angularVelocity)
            guard
                let hit = PolygonCollision.resolve(body, wall: wall, restitution: table.restitution)
            else { continue }
            pucks[index].position += hit.positionShift
            pucks[index].velocity = hit.velocity
            pucks[index].angularVelocity = hit.angularVelocity
            if hit.impactSpeed > 0 { events.append(.wallBounce(speed: hit.impactSpeed)) }
        }
    }

    /// The walls a polygon at `p` can hit this tick: goal posts inside a recess
    /// (else the solid side walls), plus each short wall away from its opening.
    private func activeWalls(for p: Vec2) -> [PolygonCollision.Wall] {
        let field = table.puckField
        var walls: [PolygonCollision.Wall] = []
        if let goal = goalRecess(p) {
            walls.append(.init(normal: Vec2(-1, 0), limit: -goal.postLeft))
            walls.append(.init(normal: Vec2(1, 0), limit: goal.postRight))
        } else if table.sideWalls == .solid {
            walls.append(.init(normal: Vec2(-1, 0), limit: -field.minX))
            walls.append(.init(normal: Vec2(1, 0), limit: field.maxX))
        }
        if !table.goal(.top).admitsOpening(p.x) {
            walls.append(.init(normal: Vec2(0, -1), limit: -field.minY))
        }
        if !table.goal(.bottom).admitsOpening(p.x) {
            walls.append(.init(normal: Vec2(0, 1), limit: field.maxY))
        }
        return walls
    }
}

extension Double {
    /// `sqrt` of a value floored at zero, for lengths that can dip a hair
    /// negative on float dust.
    fileprivate var squareRootClamped: Double { Swift.max(0, self).squareRoot() }
}
