import PuckaroundCore
import SwiftUI

/// **The remembered names, tended.** Every name the app knows — tournament
/// benches and arcade boards draw from this one pool — each with its kits:
/// tap a name to open its colors (and the way to forget it), type below to
/// add one. Lives in Settings and behind the arcade shelf's Names button, so
/// the pool is manageable wherever it's used, not only on tournament night.
struct PoolManager: View {
    @AppStorage("puckaround.playerNames") private var savedPool = Data()
    @State private var pool: [NamedPlayer] = []
    /// The pool name whose kits are open in the editor, if any.
    @State private var editing: String?

    var body: some View {
        VStack(spacing: 8) {
            if pool.isEmpty {
                Text("No names yet", bundle: .module)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Neon.inkSoft)
            } else {
                KitBench(
                    players: pool, editing: $editing,
                    onPick: { name, kit in setKit(kit, for: name) },
                    onReset: { name in setKit(.assigned(to: name), for: name) },
                    onForget: { name in
                        pool.removeAll { $0.name == name }
                        editing = nil
                        save()
                    }
                ) { player in
                    nameCell(player)
                }
            }
            NameEntryField(poolEditing: $editing, onAdd: add)
        }
        .onAppear { pool = PlayerPool.decode(savedPool) }
        // The pool can change under this view — Settings' "Forget all names"
        // writes the same storage this manager shows.
        .onChangeCompat(of: savedPool) { pool = PlayerPool.decode($0) }
    }

    /// One name with its kit swatch — the whole cell opens the editor below
    /// its row (managing IS the action here, so the big target does the main
    /// thing); a ring marks the open one.
    private func nameCell(_ player: NamedPlayer) -> some View {
        let tint = SeatPalette.neon(player.kit.home)
        let open = editing == player.name
        return Button {
            editing = open ? nil : player.name
        } label: {
            HStack(spacing: 8) {
                Text(verbatim: player.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    Circle().fill(tint).frame(width: 9, height: 9)
                    Circle().fill(SeatPalette.neon(player.kit.away)).frame(width: 9, height: 9)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tint.opacity(open ? 1 : 0.5), lineWidth: 1.5)
            )
            // An outlined cell's clear middle takes no hits on its own —
            // this makes the whole face the target (NeonButton's fix).
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func add(_ name: String, kit: PlayerKit) {
        guard !pool.contains(where: { $0.name == name }) else { return }
        pool.insert(NamedPlayer(name: name, kit: kit), at: 0)
        save()
    }

    private func setKit(_ kit: PlayerKit, for name: String) {
        guard let index = pool.firstIndex(where: { $0.name == name }) else { return }
        pool[index].kit = kit
        save()
    }

    private func save() {
        savedPool = PlayerPool.encode(pool)
    }
}

/// The manager on its own card — what the arcade shelf's Names button opens.
struct NamesSheet: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // The scrim every sheet leads with — without it the shelf stayed
            // visible AND tappable beside the card on wide screens, so a
            // cabinet could launch under the open sheet.
            Color.black.opacity(0.85).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 0) {
                NeonSheetHeader(title: "Names", onClose: onClose)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                ScrollView {
                    PoolManager()
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                }
            }
            .frame(maxWidth: 440)
            .background(NeonCard())
            .padding(16)
        }
    }
}
