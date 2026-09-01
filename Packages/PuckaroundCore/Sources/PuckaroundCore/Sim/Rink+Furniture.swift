import Foundation

/// The arcade furniture's physics — bumpers that kick, bricks that break, and
/// the mercy rule for a puck dead in an unmanned half. Split from
/// Rink+Physics to keep that file inside the length limit; same struct, same
/// fixed-index determinism. Internal rather than private: the step loop that
/// calls these lives in the other file.
extension Rink {
    /// Bumpers: fixed discs that bounce the puck and kick it faster — pinball
    /// furniture riding the same circle math as a mallet that never moves.
    /// Fixed index order, so the mayhem stays deterministic. Only a real hit
    /// (closing speed) kicks and clangs; a puck resting against a bumper is
    /// pushed clear without being machine-gunned to the moon.
    mutating func collideBumpers(puckAt index: Int) {
        for bumper in table.bumpers {
            let reach = table.puckRadius + bumper.radius
            let offset = pucks[index].position - bumper.position
            guard offset.length < reach else { continue }
            let normal = offset.length > 0 ? offset.normalized : Vec2(0, -1)
            pucks[index].position = bumper.position + normal * reach
            let closing = pucks[index].velocity.dot(normal)
            guard closing < 0 else { continue }
            pucks[index].velocity -= normal * ((1 + table.restitution) * closing)
            pucks[index].velocity += normal * bumper.kick
            events.append(.bumperHit(speed: -closing))
        }
    }

    /// Bricks: the puck smashes the first brick it overlaps (index order, so
    /// deterministic), bouncing off it as it breaks — one brick per tick per
    /// puck; a seam-mate waits for the next tick. A graze while moving away
    /// pushes clear without breaking. Shaped pucks smash by their bounding
    /// circle, like puck-puck.
    mutating func collideBricks(puckAt index: Int) {
        let r = table.puckRadius
        for brickIndex in bricks.indices {
            let rect = bricks[brickIndex].rect
            let p = pucks[index].position
            let closest = Vec2(
                min(max(p.x, rect.minX), rect.maxX), min(max(p.y, rect.minY), rect.maxY))
            let offset = p - closest
            guard offset.lengthSquared < r * r else { continue }
            let normal =
                offset.length > 0
                ? offset.normalized : Vec2(0, pucks[index].velocity.y > 0 ? -1 : 1)
            pucks[index].position = closest + normal * r
            let closing = pucks[index].velocity.dot(normal)
            guard closing < 0 else { return }
            pucks[index].velocity -= normal * ((1 + table.restitution) * closing)
            // A sturdy brick chips and holds; the last hit removes it.
            if bricks[brickIndex].hits > 1 {
                bricks[brickIndex].hits -= 1
                events.append(.brickChipped(speed: -closing))
            } else {
                bricks.remove(at: brickIndex)
                events.append(.brickBroken(speed: -closing))
            }
            return
        }
    }

    /// A puck doomed in a half nobody mans re-serves instead of stalling the
    /// game — and it doesn't wait for the last pixel of drift: once it's past
    /// the lone side's reach and too slow for its remaining travel to bring it
    /// back, reach furniture, or find the goal, only walls remain and its fate
    /// is sealed, so it beams out early. No foul and no cost: a soft shot that
    /// ran out isn't a mistake worth a life. One-puck tables only — another
    /// puck could still knock a doomed one loose.
    mutating func rescueDeadPuck(at index: Int) {
        guard phase == .playing, pucks.count == 1 else { return }
        let puck = pucks[index]
        for side in Side.allCases where table.format.hands(on: side) == Format.Hands.none {
            // The manned mallet, kissing the center line, reaches a puck-radius
            // over it; past that only the furniture and the goal can act.
            let beyond =
                side == .top
                ? puck.position.y < table.center.y - table.puckRadius
                : puck.position.y > table.center.y + table.puckRadius
            guard beyond else { continue }
            // Total remaining travel under exponential drag is at most v/drag,
            // and walls only bleed speed — the bound survives any bounce.
            let speed = puck.velocity.length
            if speed == 0 || speed / table.drag < doomDistance(from: puck.position, into: side) {
                events.append(.puckBeamed(from: puck.position))
                serve(puckAt: index, to: rules.serveTo ?? side.opponent)
            }
        }
    }

    /// How far the puck is from ANYTHING on `side`'s unmanned half that could
    /// still change its fate: the manned side's reach line, the goal mouth, a
    /// bumper, a standing brick. Walls aren't listed — they only bleed speed.
    private func doomDistance(from p: Vec2, into side: Side) -> Double {
        let field = table.puckField
        var nearest =
            side == .top
            ? (table.center.y - table.puckRadius) - p.y
            : p.y - (table.center.y + table.puckRadius)
        let goal = table.goal(side)
        let wallY = side == .top ? field.minY : field.maxY
        let onMouth = Vec2(min(max(p.x, goal.postLeft), goal.postRight), wallY)
        nearest = min(nearest, p.distance(to: onMouth))
        for bumper in table.bumpers {
            let surface = p.distance(to: bumper.position) - bumper.radius - table.puckRadius
            nearest = min(nearest, surface)
        }
        for brick in bricks {
            let rect = brick.rect
            let closest = Vec2(
                min(max(p.x, rect.minX), rect.maxX), min(max(p.y, rect.minY), rect.maxY))
            nearest = min(nearest, p.distance(to: closest) - table.puckRadius)
        }
        return nearest
    }
}
