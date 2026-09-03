import PuckaroundCore
import SwiftUI

/// **Tonight's players, and the shape of their evening.** A pool of remembered
/// names — tap one to seat it, its swatch to dress or forget it — plus a field
/// for someone new, so typing happens once per friend, ever. The lineup plays
/// in the order picked. No profiles: the pool is autocomplete, nothing more.
struct RosterSheet: View {
    /// The evening's match rules — the same stored setup New match edits.
    @Binding var setup: Setup
    let onStart: ([String], EveningPlan) -> Void
    let onClose: () -> Void

    /// The remembered pool, most recently used first, JSON in storage.
    @AppStorage("puckaround.playerNames") private var savedPool = Data()
    @State private var pool: [NamedPlayer] = []
    @State private var roster: [String] = []
    /// The pool name whose kits are open in the editor, if any.
    @State private var editing: String?
    @State private var shape = Evening.Shape.winnerStays
    /// League only: everyone meets twice (return legs) instead of once.
    @State private var doubleRound = false

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            NeonSheetHeader(title: "Tournament", onClose: onClose)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 24) {
                    section("Format") { shapePicker }
                    section("Lineup") { lineup }
                    if !benched.isEmpty {
                        section("Names") { bench }
                    }
                    NameEntryField(poolEditing: $editing, onAdd: add)
                    // The match rules, right here — no separate step. No players
                    // picker: a pairing is two people, so it's always 1v1.
                    SetupControls(setup: $setup, showsFormat: false)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            NeonButton(title: "Start tournament", tint: Neon.cyan, prominent: true) {
                start()
            }
            .opacity(canStart ? 1 : 0.4)
            .disabled(!canStart)
            .padding(24)
        }
        .frame(maxWidth: 440)
        .background(NeonCard())
        .padding(16)
        .onAppear { pool = PlayerPool.decode(savedPool) }
        // Settings can rewrite the same pool while a lobby idles behind it.
        .onChangeCompat(of: savedPool) { pool = PlayerPool.decode($0) }
    }

    /// Tonight's players in play order — the first two take the table. Tapping
    /// a name benches it again.
    private var lineup: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(roster, id: \.self) { name in
                chip(name, tint: kitColor(name), selected: true) {
                    roster.removeAll { $0 == name }
                }
            }
        }
    }

    /// Remembered names not yet in the lineup: tap one to seat it, its kit
    /// swatch to dress — or forget — it.
    private var bench: some View {
        KitBench(
            players: benched, editing: $editing,
            onPick: { name, kit in setKit(kit, for: name) },
            onReset: { name in setKit(.assigned(to: name), for: name) },
            onForget: { name in
                pool.removeAll { $0.name == name }
                editing = nil
                savePool()
            }
        ) { player in
            poolChip(player)
        }
    }

    /// One name, once — it joins tonight's lineup and the remembered pool.
    private func add(_ name: String, kit: PlayerKit) {
        guard !roster.contains(name) else { return }
        roster.append(name)
        if !pool.contains(where: { $0.name == name }) {
            pool.insert(NamedPlayer(name: name, kit: kit), at: 0)
            savePool()
        }
    }

    private func setKit(_ kit: PlayerKit, for name: String) {
        guard let index = pool.firstIndex(where: { $0.name == name }) else { return }
        pool[index].kit = kit
        savePool()
    }

    private func chip(
        _ name: String, tint: Color, selected: Bool, act: @escaping () -> Void
    ) -> some View {
        Button(action: act) {
            Text(verbatim: name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(1)
                .foregroundStyle(selected ? Neon.ground : tint)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? tint : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    tint.opacity(selected ? 1 : 0.5), lineWidth: 1.5))
                )
                // An outlined chip's clear middle takes no hits on its own —
                // this makes the whole face the target (NeonButton's fix).
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func section(_ key: LocalizedStringKey, @ViewBuilder body: () -> some View)
        -> some View
    {
        VStack(spacing: 12) {
            NeonCaption(title: key, size: 15)
            body()
        }
    }

    /// Two or more to play at all; a bracket and a league also cap the field —
    /// a sheet must fit a screen, a season must fit an evening.
    private var canStart: Bool {
        guard roster.count >= 2 else { return false }
        switch shape {
        case .winnerStays: return true
        case .bracket: return roster.count <= Bracket.maxPlayers
        case .league: return roster.count <= League.maxPlayers
        }
    }

    /// The shape of the evening: an endless line, a knockout sheet, or a
    /// season — which also picks its length here.
    private var shapePicker: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                shapeOption("Winner stays", .winnerStays)
                shapeOption("Bracket", .bracket)
                shapeOption("League", .league)
            }
            if shape == .league {
                HStack(spacing: 10) {
                    NeonChoicePill(title: "Once", selected: !doubleRound) { doubleRound = false }
                    NeonChoicePill(title: "Twice", selected: doubleRound) { doubleRound = true }
                }
            }
        }
    }

    private func shapeOption(_ label: LocalizedStringKey, _ s: Evening.Shape) -> some View {
        NeonChoicePill(title: label, selected: shape == s) { shape = s }
    }

    /// Pool players not seated tonight.
    private var benched: [NamedPlayer] { pool.filter { !roster.contains($0.name) } }

    /// Room enough for a real first name, short enough to fit by a score.
    static let maxNameLength = 12

    /// Tonight's names float to the front of the pool, so next time they're the
    /// first chips under the thumb.
    private func start() {
        let seated = roster.map { name in
            pool.first { $0.name == name } ?? NamedPlayer(name: name, kit: .assigned(to: name))
        }
        pool = seated + pool.filter { !roster.contains($0.name) }
        savePool()
        switch shape {
        case .winnerStays: onStart(roster, .winnerStays)
        case .bracket: onStart(roster, .bracket)
        case .league: onStart(roster, .league(doubleRound: doubleRound))
        }
    }

    private func savePool() {
        savedPool = PlayerPool.encode(pool)
    }
}

// MARK: - Bench cell

extension RosterSheet {
    /// One bench cell: the chip that seats, and the kit swatch into the
    /// editor. Forgetting lives in the editor — no delete sits a stray thumb
    /// from the swatch.
    fileprivate func poolChip(_ player: NamedPlayer) -> some View {
        HStack(spacing: 0) {
            chip(player.name, tint: SeatPalette.neon(player.kit.home), selected: false) {
                roster.append(player.name)
            }
            kitDot(player)
        }
    }

    /// The kit swatch on a pool chip — home over away — and the way into the
    /// editor below its row; a ring marks it while its colors are open.
    fileprivate func kitDot(_ player: NamedPlayer) -> some View {
        Button {
            editing = editing == player.name ? nil : player.name
        } label: {
            VStack(spacing: 2) {
                Circle().fill(SeatPalette.neon(player.kit.home)).frame(width: 9, height: 9)
                Circle().fill(SeatPalette.neon(player.kit.away)).frame(width: 9, height: 9)
            }
            // Width buys hit area (the chip beside it flexes); the dots stay small.
            .frame(width: 38, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(
                        Neon.ink.opacity(editing == player.name ? 0.9 : 0), lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Kit", bundle: .module))
    }

    /// The color a name's chip wears — its home kit.
    fileprivate func kitColor(_ name: String) -> Color {
        SeatPalette.neon(PlayerPool.kit(for: name, in: pool).home)
    }
}

/// What the roster sheet hands back: the shape, with whatever the shape needs
/// picked alongside it — a league carries its season length.
enum EveningPlan {
    case winnerStays
    case bracket
    case league(doubleRound: Bool)
}
