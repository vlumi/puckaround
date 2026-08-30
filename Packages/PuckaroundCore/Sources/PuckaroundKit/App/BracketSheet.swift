import PuckaroundCore
import SwiftUI

/// **The sheet, drawn.** Rounds as columns — the first the tallest, the
/// champion's slot last — with elbow connectors carrying winners rightward.
/// Byes are gaps, losers dim out, the live pairing wears the end colors, and a
/// decided champion glows. Wide fields scroll sideways; the tallest column is
/// sized to fit the card without vertical scrolling, even at the 32-player cap.
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
                let y = pitch * (CGFloat(slot) + 0.5)
                if round + 1 < rounds.count {
                    connect(
                        from: CGPoint(x: x, y: y), round: round, slot: slot, size: size,
                        in: &context)
                }
                guard let name = slots[slot] else { continue }
                drawName(
                    name, at: CGPoint(x: x + 4, y: y), round: round, slot: slot, in: &context)
            }
        }
    }

    /// The elbow from a slot to its parent: out to the column's junction, up or
    /// down to the parent's height, and into the parent's slot.
    private func connect(
        from point: CGPoint, round: Int, slot: Int, size: CGSize, in context: inout GraphicsContext
    ) {
        let junction = point.x + columnWidth - 10
        let parentPitch = size.height / CGFloat(rounds[round + 1].count)
        let parentY = parentPitch * (CGFloat(slot / 2) + 0.5)
        var path = Path()
        path.move(to: CGPoint(x: point.x + columnWidth - 26, y: point.y))
        path.addLine(to: CGPoint(x: junction, y: point.y))
        path.addLine(to: CGPoint(x: junction, y: parentY))
        path.addLine(to: CGPoint(x: point.x + columnWidth + 2, y: parentY))
        context.stroke(path, with: .color(Neon.inkSoft.opacity(0.35)), lineWidth: 1)
    }

    private func drawName(
        _ name: String, at point: CGPoint, round: Int, slot: Int, in context: inout GraphicsContext
    ) {
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
