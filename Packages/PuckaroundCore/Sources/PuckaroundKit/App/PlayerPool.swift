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
/// and no pick is ever refused. Headed by the name it dresses, in its home
/// color, so there's no guessing whose kits are open.
struct KitEditor: View {
    let name: String
    let kit: PlayerKit
    let onPick: (PlayerKit) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(verbatim: name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(SeatPalette.neon(kit.home))
                .lineLimit(1)
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
