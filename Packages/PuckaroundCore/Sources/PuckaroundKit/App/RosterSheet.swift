import PuckaroundCore
import SwiftUI

/// **Tonight's players, and the shape of their evening.** A pool of remembered
/// names — tap one to seat it, × to forget it — plus a field for someone new,
/// so typing happens once per friend, ever. The lineup plays in the order
/// picked. No profiles: the pool is autocomplete, nothing more.
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
    /// The kit picked for the name being typed. Nil follows the auto
    /// assignment as the text changes; opening the picker freezes it — that's
    /// a pick, so the hash stops moving under the user.
    @State private var draftKit: PlayerKit?
    @State private var editingDraft = false
    @State private var newName = ""
    @State private var shape = Evening.Shape.winnerStays
    /// League only: everyone meets twice (return legs) instead of once.
    @State private var doubleRound = false
    @FocusState private var nameFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 24) {
                    section("Format") { shapePicker }
                    section("Lineup") { lineup }
                    if !benched.isEmpty {
                        section("Names") { poolChips }
                    }
                    addField
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
        .onAppear(perform: load)
    }

    private var header: some View {
        ZStack {
            Text("Tournament", bundle: .module)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Neon.ink)
            HStack {
                Spacer()
                NeonIconButton(systemName: "xmark", label: "Close", action: onClose)
            }
        }
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

    /// Remembered names not yet in the lineup, two per row: tap to seat, the
    /// kit swatch to dress — or forget — them. The kit editor slots in right
    /// under the row of the name it dresses, so with a long bench the open
    /// rows are never far from their owner.
    private var poolChips: some View {
        VStack(spacing: 8) {
            ForEach(poolRows, id: \.first!.name) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.name) { player in
                        poolChip(player)
                    }
                    if row.count == 1 {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
                if let editing, row.contains(where: { $0.name == editing }),
                    let i = pool.firstIndex(where: { $0.name == editing })
                {
                    KitEditor(kit: pool[i].kit) { picked in
                        pool[i].kit = picked
                        savePool()
                    } onForget: {
                        pool.removeAll { $0.name == editing }
                        self.editing = nil
                        savePool()
                    }
                }
            }
        }
    }

    /// One name, once — it joins tonight's lineup and the remembered pool. The
    /// field keeps focus after adding, so a whole lineup types without leaving
    /// the keyboard; the + is the same action made visible.
    private var addField: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                TextField(text: $newName, prompt: Text("Add name", bundle: .module)) {
                    Text("Add name", bundle: .module)
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Neon.ink)
                .textFieldStyle(.plain)
                .submitLabel(.next)
                .focused($nameFocused)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Neon.inkSoft.opacity(0.6), lineWidth: 1.5)
                )
                .onSubmit(add)
                if !draftName.isEmpty {
                    draftDot
                }
                addButton
            }
            // The field itself is never clamped — an IME composes a long
            // reading before it collapses into a short name. Over-long simply
            // can't be added, and this says why.
            if overLong {
                Text("At most \(RosterSheet.maxNameLength) characters", bundle: .module)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Neon.magenta.opacity(0.85))
            }
            if editingDraft, !draftName.isEmpty {
                KitEditor(kit: currentDraftKit) { draftKit = $0 }
            }
        }
        // An emptied field is the next person starting over: the pick clears
        // and the swatch goes back to following the typed name.
        .onChange(of: newName) { _ in
            if draftName.isEmpty {
                draftKit = nil
                editingDraft = false
            }
        }
    }

    private var addButton: some View {
        Button(action: add) {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(canAdd ? Neon.ground : Neon.inkSoft)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canAdd ? Neon.cyan : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    canAdd ? Neon.cyan : Neon.inkSoft.opacity(0.6),
                                    lineWidth: 1.5)))
        }
        .buttonStyle(.plain)
        .disabled(!canAdd)
        .accessibilityLabel(Text("Add name", bundle: .module))
    }

    /// Non-empty and within the cap: over-long input disables adding instead of
    /// clamping the field, which would break IME composition mid-typing.
    private var canAdd: Bool {
        let name = newName.trimmingCharacters(in: .whitespaces)
        return !name.isEmpty && name.count <= RosterSheet.maxNameLength
    }

    private var overLong: Bool {
        newName.trimmingCharacters(in: .whitespaces).count > RosterSheet.maxNameLength
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
                                    tint.opacity(selected ? 1 : 0.5), lineWidth: 1.5)))
        }
        .buttonStyle(.plain)
    }

    private func section(_ key: LocalizedStringKey, @ViewBuilder body: () -> some View)
        -> some View
    {
        VStack(spacing: 12) {
            Text(key, bundle: .module)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Neon.inkSoft)
                .textCase(.uppercase)
                .kerning(2)
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
                    seasonOption("Once", false)
                    seasonOption("Twice", true)
                }
            }
        }
    }

    private func shapeOption(_ label: LocalizedStringKey, _ s: Evening.Shape) -> some View {
        pill(label, selected: shape == s) { shape = s }
    }

    private func seasonOption(_ label: LocalizedStringKey, _ twice: Bool) -> some View {
        pill(label, selected: doubleRound == twice) { doubleRound = twice }
    }

    private func pill(
        _ label: LocalizedStringKey, selected: Bool, act: @escaping () -> Void
    ) -> some View {
        Button(action: act) {
            Text(label, bundle: .module)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Neon.ground : Neon.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 10)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? Neon.ink : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    Neon.ink.opacity(selected ? 1 : 0.4), lineWidth: 1.5)))
        }
        .buttonStyle(.plain)
    }

    /// Pool players not seated tonight.
    private var benched: [NamedPlayer] { pool.filter { !roster.contains($0.name) } }

    /// Room enough for a real first name, short enough to fit by a score.
    static let maxNameLength = 12

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        // An over-long name stays put to be edited down, never silently cut.
        guard name.count <= RosterSheet.maxNameLength else { return }
        let kit = currentDraftKit
        newName = ""
        draftKit = nil
        editingDraft = false
        // Focus stays in the field, so the next name needs no extra touch.
        nameFocused = true
        guard !name.isEmpty, !roster.contains(name) else { return }
        roster.append(name)
        if !pool.contains(where: { $0.name == name }) {
            pool.insert(NamedPlayer(name: name, kit: kit), at: 0)
            savePool()
        }
    }

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

    private func load() {
        pool = PlayerPool.decode(savedPool)
    }

    private func savePool() {
        savedPool = PlayerPool.encode(pool)
    }
}

// MARK: - Kits

extension RosterSheet {
    /// One bench row's cell: the chip and its kit swatch. Forgetting lives in
    /// the swatch's editor — no delete sits a stray thumb from the swatch.
    fileprivate func poolChip(_ player: NamedPlayer) -> some View {
        HStack(spacing: 0) {
            chip(player.name, tint: SeatPalette.neon(player.kit.home), selected: false) {
                roster.append(player.name)
            }
            kitDot(player)
        }
    }

    /// The bench, two seats per row — fixed rows (not an adaptive grid) so the
    /// kit editor can slot under exactly the right one.
    fileprivate var poolRows: [[NamedPlayer]] {
        stride(from: 0, to: benched.count, by: 2).map {
            Array(benched[$0..<min($0 + 2, benched.count)])
        }
    }

    /// The kit swatch on a pool chip — home over away — and the way into the
    /// editor below its row; a ring marks it while its colors are open.
    fileprivate func kitDot(_ player: NamedPlayer) -> some View {
        Button {
            editing = editing == player.name ? nil : player.name
            editingDraft = false
        } label: {
            VStack(spacing: 2) {
                Circle().fill(SeatPalette.neon(player.kit.home)).frame(width: 9, height: 9)
                Circle().fill(SeatPalette.neon(player.kit.away)).frame(width: 9, height: 9)
            }
            .frame(width: 30, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(
                        Neon.ink.opacity(editing == player.name ? 0.9 : 0), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Kit", bundle: .module))
    }

    /// The color a name's chip wears — its home kit.
    fileprivate func kitColor(_ name: String) -> Color {
        SeatPalette.neon(PlayerPool.kit(for: name, in: pool).home)
    }

    /// The name being typed, trimmed — what add() would seat.
    fileprivate var draftName: String { newName.trimmingCharacters(in: .whitespaces) }

    /// The kit the typed name would wear: the frozen pick, or the live auto
    /// assignment following the text.
    fileprivate var currentDraftKit: PlayerKit { draftKit ?? .assigned(to: draftName) }

    /// The kit swatch beside the add field: it previews the auto kit as the
    /// name is typed, and tapping it opens the picker — which freezes the kit,
    /// since opening it means these colors are chosen.
    fileprivate var draftDot: some View {
        Button {
            draftKit = currentDraftKit
            editingDraft.toggle()
            editing = nil
        } label: {
            VStack(spacing: 2) {
                Circle().fill(SeatPalette.neon(currentDraftKit.home)).frame(width: 9, height: 9)
                Circle().fill(SeatPalette.neon(currentDraftKit.away)).frame(width: 9, height: 9)
            }
            .frame(width: 22, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Neon.ink.opacity(editingDraft ? 0.9 : 0), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Kit", bundle: .module))
    }
}

/// What the roster sheet hands back: the shape, with whatever the shape needs
/// picked alongside it — a league carries its season length.
enum EveningPlan {
    case winnerStays
    case bracket
    case league(doubleRound: Bool)
}
