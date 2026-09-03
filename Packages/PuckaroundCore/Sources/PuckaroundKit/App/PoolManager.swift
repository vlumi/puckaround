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
    /// The kit picked for the name being typed. Nil follows the auto
    /// assignment as the text changes; opening the picker freezes it — that's
    /// a pick, so the hash stops moving under the user (the roster's rule).
    @State private var draftKit: PlayerKit?
    @State private var editingDraft = false
    @State private var newName = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            if pool.isEmpty {
                Text("No names yet", bundle: .module)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Neon.inkSoft)
            } else {
                nameRows
            }
            addField
        }
        .onAppear { pool = PlayerPool.decode(savedPool) }
        // The pool can change under this view — Settings' "Forget all names"
        // writes the same storage this manager shows.
        .onChangeCompat(of: savedPool) { pool = PlayerPool.decode($0) }
    }

    /// The pool, two names per row — fixed rows (not an adaptive grid) so the
    /// kit editor can slot under exactly the right one. Unlike the roster's
    /// bench, tapping the name itself opens its kits: here managing IS the
    /// action, so the big target does the main thing.
    private var nameRows: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.first!.name) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.name) { player in
                        nameCell(player)
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
                        save()
                    } onReset: {
                        pool[i].kit = .assigned(to: pool[i].name)
                        save()
                    } onForget: {
                        pool.removeAll { $0.name == editing }
                        self.editing = nil
                        save()
                    }
                }
            }
        }
    }

    private var rows: [[NamedPlayer]] {
        stride(from: 0, to: pool.count, by: 2).map {
            Array(pool[$0..<min($0 + 2, pool.count)])
        }
    }

    /// One name with its kit swatch — the whole cell opens the editor below
    /// its row; a ring marks the open one.
    private func nameCell(_ player: NamedPlayer) -> some View {
        let tint = SeatPalette.neon(player.kit.home)
        let open = editing == player.name
        return Button {
            editing = open ? nil : player.name
            editingDraft = false
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

    /// One name, once — straight into the pool, dressed in the previewed kit.
    /// The field keeps focus after adding, so several names type in a row.
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
                // A faint well under a brighter border — the outline alone
                // read as decoration, not as a place to type.
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Neon.ink.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Neon.ink.opacity(0.7), lineWidth: 1.5))
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
                KitEditor(
                    kit: currentDraftKit, onPick: { draftKit = $0 }, onReset: { draftKit = nil })
            }
        }
        // An emptied field is the next person starting over: the pick clears
        // and the swatch goes back to following the typed name.
        .onChangeCompat(of: newName) { _ in
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

    /// The kit swatch beside the add field: it previews the auto kit as the
    /// name is typed, and tapping it opens the picker — which freezes the kit,
    /// since opening it means these colors are chosen.
    private var draftDot: some View {
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
                    .strokeBorder(Neon.ink.opacity(editingDraft ? 0.9 : 0), lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Kit", bundle: .module))
    }

    private var draftName: String { newName.trimmingCharacters(in: .whitespaces) }

    private var currentDraftKit: PlayerKit { draftKit ?? .assigned(to: draftName) }

    private var canAdd: Bool {
        !draftName.isEmpty && draftName.count <= RosterSheet.maxNameLength
    }

    private var overLong: Bool { draftName.count > RosterSheet.maxNameLength }

    private func add() {
        let name = draftName
        // An over-long name stays put to be edited down, never silently cut.
        guard !name.isEmpty, name.count <= RosterSheet.maxNameLength else { return }
        let kit = currentDraftKit
        newName = ""
        draftKit = nil
        editingDraft = false
        nameFocused = true
        guard !pool.contains(where: { $0.name == name }) else { return }
        pool.insert(NamedPlayer(name: name, kit: kit), at: 0)
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
        VStack(spacing: 0) {
            header
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

    private var header: some View {
        ZStack {
            Text("Names", bundle: .module)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Neon.ink)
            HStack {
                Spacer()
                NeonIconButton(systemName: "xmark", label: "Close", action: onClose)
            }
        }
    }
}
