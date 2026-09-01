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
            events.append(.brickBroken(speed: -closing))
            bricks.remove(at: brickIndex)
            return
        }
    }

    /// A puck that dies in a half nobody mans — at rest, past the lone side's
    /// reach — re-serves instead of stalling the game forever. No foul and no
    /// cost: a soft shot that ran out isn't a mistake worth a life. Only solo
    /// tables have an unmanned half, so the couch never sees this.
    mutating func rescueDeadPuck(at index: Int) {
        guard phase == .playing, pucks[index].velocity == .zero else { return }
        let p = pucks[index].position
        for side in Side.allCases where table.format.hands(on: side) == Format.Hands.none {
            // The manned mallet, kissing the center line, reaches a puck-radius
            // over it; anything at rest beyond that is out of every hand.
            let beyondReach =
                side == .top
                ? p.y < table.center.y - table.puckRadius
                : p.y > table.center.y + table.puckRadius
            if beyondReach {
                serve(puckAt: index, to: rules.serveTo ?? side.opponent)
            }
        }
    }
}
