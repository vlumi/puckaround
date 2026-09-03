import PuckaroundCore
import SwiftUI

/// The one name-entry row — field, live kit swatch, add button — with the
/// draft-kit freeze and the IME-safe over-long guard. The roster seats what it
/// adds and the pool manager just pools it: the entry logic lives once, and
/// the caller only decides where a committed name goes.
struct NameEntryField: View {
    /// The pool editor open elsewhere on the sheet, if any — opening the draft
    /// editor closes it and vice versa, so one set of swatch rows shows at a
    /// time.
    @Binding var poolEditing: String?
    /// A valid, trimmed name was committed wearing `kit`.
    let onAdd: (String, PlayerKit) -> Void

    /// The kit picked for the name being typed. Nil follows the auto
    /// assignment as the text changes; opening the picker freezes it — that's
    /// a pick, so the hash stops moving under the user.
    @State private var draftKit: PlayerKit?
    @State private var editingDraft = false
    @State private var newName = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                field
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
        .onChangeCompat(of: poolEditing) { open in
            if open != nil { editingDraft = false }
        }
    }

    private var field: some View {
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
        // A faint well under a brighter border — the outline alone read as
        // decoration, not as a place to type.
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Neon.ink.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Neon.ink.opacity(0.7), lineWidth: 1.5))
        )
        .onSubmit(add)
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
            if editingDraft { poolEditing = nil }
        } label: {
            VStack(spacing: 2) {
                Circle().fill(SeatPalette.neon(currentDraftKit.home)).frame(width: 9, height: 9)
                Circle().fill(SeatPalette.neon(currentDraftKit.away)).frame(width: 9, height: 9)
            }
            .frame(width: 32, height: 44)
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
        // Focus stays in the field, so the next name needs no extra touch.
        nameFocused = true
        onAdd(name, kit)
    }
}

/// The pool laid out two per row, the kit editor slotted under the row of the
/// name it dresses — fixed rows (not an adaptive grid), so the open editor is
/// never far from its owner. The cell content is the caller's (the roster's
/// chip + swatch, the manager's full-width cell); the editor's verbs write
/// back through the callbacks.
struct KitBench<Cell: View>: View {
    let players: [NamedPlayer]
    /// The pool name whose kits are open in the editor, if any.
    @Binding var editing: String?
    let onPick: (String, PlayerKit) -> Void
    let onReset: (String) -> Void
    let onForget: (String) -> Void
    @ViewBuilder let cell: (NamedPlayer) -> Cell

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.first!.name) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.name) { player in
                        cell(player)
                    }
                    if row.count == 1 {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
                if let editing, let player = row.first(where: { $0.name == editing }) {
                    KitEditor(kit: player.kit) { picked in
                        onPick(editing, picked)
                    } onReset: {
                        onReset(editing)
                    } onForget: {
                        onForget(editing)
                    }
                }
            }
        }
    }

    private var rows: [[NamedPlayer]] {
        stride(from: 0, to: players.count, by: 2).map {
            Array(players[$0..<min($0 + 2, players.count)])
        }
    }
}
