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
    @State private var pool: [String] = []
    @State private var roster: [String] = []
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
                chip(name, selected: true) {
                    roster.removeAll { $0 == name }
                }
            }
        }
    }

    /// Remembered names not yet in the lineup: tap to seat, × to forget.
    private var poolChips: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(benched, id: \.self) { name in
                HStack(spacing: 0) {
                    chip(name, selected: false) { roster.append(name) }
                    Button {
                        pool.removeAll { $0 == name }
                        savePool()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Neon.inkSoft)
                            .frame(width: 28, height: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Forget name", bundle: .module))
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

    private func chip(_ name: String, selected: Bool, act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(verbatim: name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(1)
                .foregroundStyle(selected ? Neon.ground : Neon.ink)
                .padding(.horizontal, 12)
                .frame(height: 40)
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

    /// Pool names not seated tonight.
    private var benched: [String] { pool.filter { !roster.contains($0) } }

    /// Room enough for a real first name, short enough to fit by a score.
    static let maxNameLength = 12

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        // An over-long name stays put to be edited down, never silently cut.
        guard name.count <= RosterSheet.maxNameLength else { return }
        newName = ""
        // Focus stays in the field, so the next name needs no extra touch.
        nameFocused = true
        guard !name.isEmpty, !roster.contains(name) else { return }
        roster.append(name)
        if !pool.contains(name) {
            pool.insert(name, at: 0)
            savePool()
        }
    }

    /// Tonight's names float to the front of the pool, so next time they're the
    /// first chips under the thumb.
    private func start() {
        pool = roster + pool.filter { !roster.contains($0) }
        savePool()
        switch shape {
        case .winnerStays: onStart(roster, .winnerStays)
        case .bracket: onStart(roster, .bracket)
        case .league: onStart(roster, .league(doubleRound: doubleRound))
        }
    }

    private func load() {
        pool = (try? JSONDecoder().decode([String].self, from: savedPool)) ?? []
    }

    private func savePool() {
        savedPool = (try? JSONEncoder().encode(pool)) ?? Data()
    }
}

/// What the roster sheet hands back: the shape, with whatever the shape needs
/// picked alongside it — a league carries its season length.
enum EveningPlan {
    case winnerStays
    case bracket
    case league(doubleRound: Bool)
}
