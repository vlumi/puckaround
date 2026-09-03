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

    /// The editor's verbs on one compact line: reroll, back to the name's own
    /// colors — and, a stretch away from both, forgetting the name.
    private var actions: some View {
        HStack(spacing: 18) {
            actionButton("Shuffle", tint: Neon.ink.opacity(0.9)) {
                onPick(.random(differingFrom: kit))
            }
            if let onReset {
                actionButton("Reset", tint: Neon.ink.opacity(0.9), act: onReset)
            }
            Spacer()
            if let onForget {
                actionButton("Forget name", tint: Neon.magenta.opacity(0.9), act: onForget)
            }
        }
    }

    private func actionButton(
        _ label: LocalizedStringKey, tint: Color, act: @escaping () -> Void
    ) -> some View {
        Button(action: act) {
            Text(label, bundle: .module)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .frame(height: 32)
        }
        .buttonStyle(.plain)
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
            ForEach(0..<PlayerKit.paletteCount, id: \.self) { slot in
                Button {
                    pick(slot)
                } label: {
                    Circle()
                        .fill(SeatPalette.neon(slot))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle().strokeBorder(
                                Neon.ink.opacity(slot == selected ? 1 : 0), lineWidth: 2)
                        )
                        .padding(2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
