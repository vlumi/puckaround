import SwiftUI

/// **Tonight's players.** A pool of remembered names — tap one to seat it, × to
/// forget it — plus a field for someone new, so typing happens once per friend,
/// ever. The line plays in the order picked. No profiles: the pool is
/// autocomplete, nothing more.
struct RosterSheet: View {
    let onStart: ([String]) -> Void
    let onClose: () -> Void

    /// The remembered pool, most recently used first, JSON in storage.
    @AppStorage("puckaround.playerNames") private var savedPool = Data()
    @State private var pool: [String] = []
    @State private var roster: [String] = []
    @State private var newName = ""

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 24) {
                    section("Lineup") { lineup }
                    if !benched.isEmpty {
                        section("Names") { poolChips }
                    }
                    addField
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            NeonButton(title: "Start tournament", tint: Neon.cyan, prominent: true) {
                start()
            }
            .opacity(roster.count >= 2 ? 1 : 0.4)
            .disabled(roster.count < 2)
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

    /// One name, once — it joins tonight's lineup and the remembered pool.
    private var addField: some View {
        TextField(text: $newName, prompt: Text("Add name", bundle: .module)) {
            Text("Add name", bundle: .module)
        }
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .foregroundStyle(Neon.ink)
        .textFieldStyle(.plain)
        .submitLabel(.done)
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Neon.inkSoft.opacity(0.6), lineWidth: 1.5)
        )
        .onSubmit(add)
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

    /// Pool names not seated tonight.
    private var benched: [String] { pool.filter { !roster.contains($0) } }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        newName = ""
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
        onStart(roster)
    }

    private func load() {
        pool = (try? JSONDecoder().decode([String].self, from: savedPool)) ?? []
    }

    private func savePool() {
        savedPool = (try? JSONEncoder().encode(pool)) ?? Data()
    }
}
