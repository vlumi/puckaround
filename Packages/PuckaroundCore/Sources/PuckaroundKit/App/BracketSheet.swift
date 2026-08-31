import PuckaroundCore
import SwiftUI

/// **The sheet, drawn.** Rounds as columns — the first the tallest, the
/// champion's slot last — with elbow connectors carrying winners rightward.
/// Each connector picks up where its name ends, an undecided slot shows a dim
/// blank where the advancing winner will land, and a round-one bye hole stays
/// truly empty (nothing ever arrives there). Losers dim out, the live pairing
/// wears the end colors, and a decided champion glows. Wide fields scroll
/// sideways; the tallest column is sized to fit the card without vertical
/// scrolling, even at the 32-player cap.
struct BracketSheet: View {
    let rounds: [[String?]]
    let current: Pairing?

    private var entrants: Int { rounds[0].count }
    private var rowHeight: CGFloat { entrants > 16 ? 13 : entrants > 8 ? 17 : 24 }
    private var fontSize: CGFloat { entrants > 16 ? 8 : entrants > 8 ? 10 : 12 }
    private let columnWidth: CGFloat = 96

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .frame(
                width: CGFloat(rounds.count) * columnWidth,
                height: CGFloat(entrants) * rowHeight)
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        for round in rounds.indices {
            let slots = rounds[round]
            let pitch = size.height / CGFloat(slots.count)
            let x = CGFloat(round) * columnWidth
            for slot in slots.indices {
                let name = slots[slot]
                // A round-one hole is a bye: nothing ever arrives, draw nothing.
                if round == 0 && name == nil { continue }
                let y = pitch * (CGFloat(slot) + 0.5)
                let end = drawSlot(
                    name, at: CGPoint(x: x + 4, y: y), round: round, slot: slot, in: &context)
                if round + 1 < rounds.count {
                    connect(
                        fromX: end + 6, y: y, round: round, slot: slot, size: size,
                        in: &context)
                }
            }
        }
    }

    /// Draws a slot — the name, or a dim blank awaiting the advancing winner —
    /// and reports where it ends, so the connector picks up right after it.
    private func drawSlot(
        _ name: String?, at point: CGPoint, round: Int, slot: Int,
        in context: inout GraphicsContext
    ) -> CGFloat {
        guard let name else {
            var blank = Path()
            blank.move(to: point)
            blank.addLine(to: CGPoint(x: point.x + 28, y: point.y))
            context.stroke(blank, with: .color(Neon.inkSoft.opacity(0.5)), lineWidth: 1)
            return point.x + 28
        }
        let champion = round == rounds.count - 1
        let maxChars = Int((columnWidth - 26) / (fontSize * 0.55))
        let shown = name.count > maxChars ? String(name.prefix(maxChars - 1)) + "…" : name
        let size = champion ? fontSize + 3 : fontSize
        let text = context.resolve(
            Text(verbatim: shown).font(.system(size: size, weight: .bold, design: .rounded)))
        let colored = RinkRenderer.colored(text, color(of: name, round: round, slot: slot))
        if champion {
            var haze = context
            haze.addFilter(.blur(radius: 3))
            haze.draw(colored, at: point, anchor: .leading)
        }
        context.draw(colored, at: point, anchor: .leading)
        return point.x + text.measure(in: CGSize(width: columnWidth, height: 100)).width
    }

    /// The elbow from a slot to its parent: out from where the content ends,
    /// up or down at the column's junction, and into the parent's slot.
    private func connect(
        fromX: CGFloat, y: CGFloat, round: Int, slot: Int, size: CGSize,
        in context: inout GraphicsContext
    ) {
        let columnStart = CGFloat(round) * columnWidth
        let junction = columnStart + columnWidth - 10
        let parentPitch = size.height / CGFloat(rounds[round + 1].count)
        let parentY = parentPitch * (CGFloat(slot / 2) + 0.5)
        var path = Path()
        path.move(to: CGPoint(x: min(fromX, junction - 2), y: y))
        path.addLine(to: CGPoint(x: junction, y: y))
        path.addLine(to: CGPoint(x: junction, y: parentY))
        path.addLine(to: CGPoint(x: columnStart + columnWidth + 2, y: parentY))
        context.stroke(path, with: .color(Neon.ink.opacity(0.4)), lineWidth: 1)
    }

    /// A name's state on the sheet: live (the current pairing, in end colors),
    /// out (its match is decided and it didn't advance), or simply standing.
    private func color(of name: String, round: Int, slot: Int) -> Color {
        guard round + 1 < rounds.count else { return Neon.cyan }
        let advanced = rounds[round + 1][slot / 2]
        if advanced == nil {
            if name == current?.bottom { return Neon.magenta }
            if name == current?.top { return Neon.cyan }
            return Neon.ink
        }
        return advanced == name ? Neon.ink : Neon.inkSoft.opacity(0.55)
    }
}
