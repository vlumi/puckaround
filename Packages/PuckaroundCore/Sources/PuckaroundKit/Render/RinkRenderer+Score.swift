import PuckaroundCore
import SwiftUI

// MARK: - Score, match tally & verdict

extension RinkRenderer {
    /// The side's score, in the corner beside its goal, turned to face its
    /// player — a bright core over a glow, so a glanced number stays legible.
    static func drawScore(
        _ score: Int, seat: Seat, color: Color, projection: Projection,
        in context: inout GraphicsContext
    ) {
        let spot = scoreSpot(seat: seat, projection: projection)
        var ctx = context
        let at = projection.point(spot)
        ctx.translateBy(x: at.x, y: at.y)
        ctx.rotate(by: seat.labelAngle)
        let text = ctx.resolve(
            Text(verbatim: "\(score)").font(
                .system(size: 15 * projection.scale, weight: .black, design: .rounded)))
        var haze = ctx
        haze.addFilter(.blur(radius: 4 * projection.scale))
        haze.draw(colored(text, color.opacity(0.9)), at: .zero, anchor: .center)
        ctx.draw(colored(text, color), at: .zero, anchor: .center)
    }

    /// Where a side's score sits, in world units: the corner beside its goal at
    /// the short end. (The board's own rotation faces it to the player.)
    private static func scoreSpot(seat: Seat, projection: Projection) -> Vec2 {
        let table = projection.table
        let side = seat.side
        // The number is ~15 world units tall, so its center must sit clear of the
        // walls; a wide doubles goal narrows the strip beside the post.
        let halfGlyph = 8.0
        let strip = (table.size.x - table.goalWidth(for: side)) / 4
        let beside = max(strip, halfGlyph + 2)
        let inset = halfGlyph + 4
        return side == .top
            ? Vec2(table.size.x - beside, inset) : Vec2(beside, table.size.y - inset)
    }

    /// The player's name during a tournament, in the corner across the goal from
    /// their score — same end, other post — turned to face them like everything
    /// else that is theirs.
    static func drawEndName(
        _ name: String, seat: Seat, color: Color, projection: Projection,
        in context: inout GraphicsContext
    ) {
        let table = projection.table
        let side = seat.side
        let beside = max((table.size.x - table.goalWidth(for: side)) / 4, 10)
        let inset = 12.0
        let spot =
            side == .top ? Vec2(beside, inset) : Vec2(table.size.x - beside, table.size.y - inset)
        var ctx = context
        let at = projection.point(spot)
        ctx.translateBy(x: at.x, y: at.y)
        ctx.rotate(by: seat.labelAngle)
        let text = ctx.resolve(
            Text(verbatim: name).font(
                .system(size: 6 * projection.scale, weight: .bold, design: .rounded)))
        ctx.draw(colored(text, color.opacity(0.75)), at: .zero, anchor: .center)
    }

    /// The match tally beside a side's score: a row of pips, `won` of them filled
    /// in the side's color, the rest hollow — the games won toward the match.
    /// Sits just inboard of the score, facing the player.
    static func drawGamesTally(
        _ tally: (won: Int, of: Int), seat: Seat, color: Color, projection: Projection,
        in context: inout GraphicsContext
    ) {
        let (wins, needed) = tally
        // Sit just inboard of the score, pips laid across (the board's rotation
        // carries the row to face the player).
        let center = projection.point(tallySpot(seat: seat, projection: projection))
        let r = 1.6 * projection.scale
        let gap = 5.0 * projection.scale
        let span = (Double(needed) - 1) * gap
        for i in 0..<needed {
            let px = center.x - span / 2 + Double(i) * gap
            let dot = projection.disc(at: CGPoint(x: px, y: center.y), radius: r)
            if i < wins {
                context.fill(dot, with: .color(color))
            } else {
                context.stroke(dot, with: .color(color.opacity(0.5)), lineWidth: 1)
            }
        }
    }

    /// The tally's center, a step inboard from the score toward the middle.
    private static func tallySpot(seat: Seat, projection: Projection) -> Vec2 {
        let table = projection.table
        let side = seat.side
        let beside = max((table.size.x - table.goalWidth(for: side)) / 4, 10)
        let y = side == .top ? 22.0 : table.size.y - 22
        let x = side == .top ? table.size.x - beside : beside
        return Vec2(x, y)
    }

    /// Where and in whose colors a side's verdict is painted: its half of the
    /// table, the side's color, and whether this is a multi-game match (so the
    /// verdict names GAME vs MATCH). Bundled so the draw stays under the limit.
    struct VerdictSpot {
        let seat: Seat
        let half: CGRect
        let color: Color
        let inMatch: Bool
    }

    /// How a verdict word paints: bright and glowing for the winner, dim for the
    /// loser. Bundled so a word draw stays under the parameter limit.
    private struct Verdict {
        let won: Bool
        let shade: Color
    }

    /// The result on a side's half, turned to face its player, so both ends read
    /// it at once. In a single game it's WIN / LOSE. In a multi-game match it
    /// names the scope too — GAME won/lost between games, MATCH won/lost when the
    /// match is decided — so it's never ambiguous which just ended.
    static func drawVerdict(
        _ outcome: Rink.Outcome, at spot: VerdictSpot, in context: inout GraphicsContext
    ) {
        let (seat, half) = (spot.seat, spot.half)
        let side = seat.side
        let won = outcome.winner == side
        var ctx = context
        // Sit a little in from the side's own end toward the center line.
        let towardCenter = half.height * 0.22
        let y = side == .top ? half.maxY - towardCenter : half.minY + towardCenter
        ctx.translateBy(x: half.midX, y: y)
        ctx.rotate(by: seat.labelAngle)
        let verdict = Verdict(won: won, shade: won ? spot.color : line.opacity(0.6))
        let big = half.height * 0.16
        if spot.inMatch {
            // Scope on top (GAME / MATCH), result below (WON / LOST).
            let scope =
                outcome.endedMatch ? Text("MATCH", bundle: .module) : Text("GAME", bundle: .module)
            let result = won ? Text("WON", bundle: .module) : Text("LOST", bundle: .module)
            drawWord(scope, size: big * 0.62, dy: -big * 0.5, verdict, in: &ctx)
            drawWord(result, size: big, dy: big * 0.42, verdict, in: &ctx)
        } else {
            let word = won ? Text("WIN", bundle: .module) : Text("LOSE", bundle: .module)
            drawWord(word, size: big, dy: 0, verdict, in: &ctx)
        }
    }

    private static func drawWord(
        _ word: Text, size: CGFloat, dy: CGFloat, _ verdict: Verdict,
        in ctx: inout GraphicsContext
    ) {
        let text = ctx.resolve(word.font(.system(size: size, weight: .black, design: .rounded)))
        let at = CGPoint(x: 0, y: dy)
        if verdict.won {
            var haze = ctx
            haze.addFilter(.blur(radius: size * 0.12))
            haze.draw(colored(text, verdict.shade.opacity(0.9)), at: at, anchor: .center)
        }
        ctx.draw(colored(text, verdict.shade), at: at, anchor: .center)
    }
}
