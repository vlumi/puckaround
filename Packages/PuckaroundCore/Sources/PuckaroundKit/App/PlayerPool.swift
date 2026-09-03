import PuckaroundCore
import SwiftUI

/// One remembered player: the name (the only identity) and their kits.
struct NamedPlayer: Equatable, Codable {
    var name: String
    var kit: PlayerKit
}

/// The remembered pool's storage codec. The pool predates kits as a plain
/// `[String]`, so decoding falls back to that and dresses every name in its
/// auto-assigned kit — nobody loses their pool to the upgrade.
enum PlayerPool {
    static func decode(_ data: Data) -> [NamedPlayer] {
        if let players = try? JSONDecoder().decode([NamedPlayer].self, from: data) {
            return players
        }
        let names = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        return names.map { NamedPlayer(name: $0, kit: .assigned(to: $0)) }
    }

    static func encode(_ pool: [NamedPlayer]) -> Data {
        (try? JSONEncoder().encode(pool)) ?? Data()
    }

    /// The kit a name wears — its stored pick, or the stable auto-assignment.
    static func kit(for name: String, in pool: [NamedPlayer]) -> PlayerKit {
        pool.first { $0.name == name }?.kit ?? .assigned(to: name)
    }
}

/// The two swatch rows for one player's kits, home and away — tap to pick.
/// Picking the other row's color swaps the two, so the pair stays distinct
/// and no pick is ever refused. Whose kits are open is carried by placement
/// (the rows sit right under their name) and the ring on the open swatch.
struct KitEditor: View {
    let kit: PlayerKit
    let onPick: (PlayerKit) -> Void
    /// Back to the name's own colors — the hash assignment (or, for the add
    /// field's draft, back to following the typed name).
    var onReset: (() -> Void)?
    /// Present for pool names: forgetting lives in here, deliberately a
    /// second tap away from the bench — an × crammed beside the tiny swatch
    /// was one stray thumb from wiping a friend.
    var onForget: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            row("Home", selected: kit.home) { pick in
                var k = kit
                if pick == k.away { k.away = k.home }
                k.home = pick
                onPick(k)
            }
            row("Away", selected: kit.away) { pick in
                var k = kit
                if pick == k.home { k.home = k.away }
                k.away = pick
                onPick(k)
            }
            actions
        }
    }

    /// The editor's verbs as the app's own icon buttons — full-size circular
    /// targets, no words to crowd or outgrow the row: reroll, back to the
    /// name's own colors, and — a stretch away, in warning magenta — the way
    /// to forget the name.
    private var actions: some View {
        HStack(spacing: 10) {
            NeonIconButton(
                systemName: "shuffle", label: "Shuffle", tint: Neon.ink.opacity(0.9)
            ) {
                onPick(.random(differingFrom: kit))
            }
            if let onReset {
                NeonIconButton(
                    systemName: "arrow.counterclockwise", label: "Reset",
                    tint: Neon.ink.opacity(0.9), action: onReset)
            }
            Spacer()
            if let onForget {
                NeonIconButton(
                    systemName: "trash", label: "Forget name",
                    tint: Neon.magenta.opacity(0.9), action: onForget)
            }
        }
    }

    private func row(
        _ label: LocalizedStringKey, selected: Int, pick: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Text(label, bundle: .module)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Neon.inkSoft)
                .textCase(.uppercase)
                .kerning(1)
                .frame(width: 42, alignment: .leading)
            SwatchRow(label: label, selected: selected, pick: pick)
        }
    }
}

/// The eight hues on one scrubbable strip: tap a swatch, or drag along the
/// row — the hue under the finger swells and lifts clear of it — and release
/// on the one you want. The circles stay small; the target is the whole
/// 44-point strip, so precision is never asked of the finger. For VoiceOver
/// the strip is one adjustable element: swipe up/down steps the hue.
private struct SwatchRow: View {
    let label: LocalizedStringKey
    let selected: Int
    let pick: (Int) -> Void

    /// The swatch under the finger mid-scrub, if any.
    @State private var hovering: Int?

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<PlayerKit.paletteCount, id: \.self) { slot in
                    swatch(slot)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { hovering = slot(at: $0.location.x, width: geo.size.width) }
                    .onEnded { value in
                        pick(slot(at: value.location.x, width: geo.size.width))
                        hovering = nil
                    })
        }
        .frame(height: 44)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label, bundle: .module))
        .accessibilityValue(Text(verbatim: "\(selected + 1)/\(PlayerKit.paletteCount)"))
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? 1 : PlayerKit.paletteCount - 1
            pick((selected + step) % PlayerKit.paletteCount)
        }
    }

    private func swatch(_ slot: Int) -> some View {
        let lifted = hovering == slot
        return Circle()
            .fill(SeatPalette.neon(slot))
            .frame(width: 18, height: 18)
            .overlay(
                Circle().strokeBorder(
                    Neon.ink.opacity(slot == selected && hovering == nil ? 1 : 0),
                    lineWidth: 2)
            )
            .scaleEffect(lifted ? 1.7 : 1)
            .offset(y: lifted ? -20 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Which swatch a touch at `x` lands on, clamped to the strip — a scrub
    /// can wander past either end without losing its pick.
    private func slot(at x: CGFloat, width: CGFloat) -> Int {
        let count = PlayerKit.paletteCount
        let raw = Int(x / max(width / CGFloat(count), 1))
        return min(max(raw, 0), count - 1)
    }
}
