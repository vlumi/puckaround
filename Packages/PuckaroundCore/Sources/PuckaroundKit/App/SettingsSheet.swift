import PuckaroundCore
import SwiftUI

/// **The app's own switches** — not match settings (those live in New match):
/// the feedback toggles and the destructive resets, behind the title's gear.
/// Resets arm on the first tap and fire on the second — deliberate, without
/// a popup.
struct SettingsSheet: View {
    let onClose: () -> Void

    @AppStorage("puckaround.soundOn") private var soundOn = true
    @AppStorage("puckaround.hapticsOn") private var hapticsOn = true
    @AppStorage("puckaround.hiscores.bumperField") private var bumperBoard = Data()
    @AppStorage("puckaround.hiscores.brickWall") private var brickBoard = Data()
    @AppStorage("puckaround.hiscores.survival") private var survivalBoard = Data()
    @AppStorage("puckaround.playerNames") private var savedPool = Data()
    @State private var armedScores = false
    @State private var armedNames = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                VStack(spacing: 24) {
                    section("Feedback") {
                        toggleRow("Sounds", isOn: $soundOn)
                        toggleRow("Haptics", isOn: $hapticsOn)
                    }
                    section("Reset") {
                        dangerButton(
                            armed: $armedScores, idle: "Reset hiscores",
                            confirm: "Tap again to reset hiscores"
                        ) {
                            bumperBoard = Data()
                            brickBoard = Data()
                            survivalBoard = Data()
                        }
                        dangerButton(
                            armed: $armedNames, idle: "Forget all names",
                            confirm: "Tap again to forget all names"
                        ) {
                            savedPool = Data()
                        }
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: 440)
            .background(NeonCard())
            .padding(16)
        }
    }

    private var header: some View {
        ZStack {
            Text("Settings", bundle: .module)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Neon.ink)
            HStack {
                Spacer()
                NeonIconButton(systemName: "xmark", label: "Close", action: onClose)
            }
        }
    }

    private func toggleRow(_ label: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Text(label, bundle: .module)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Neon.ink)
            Spacer()
            choice("On", selected: isOn.wrappedValue) { isOn.wrappedValue = true }
            choice("Off", selected: !isOn.wrappedValue) { isOn.wrappedValue = false }
        }
    }

    private func choice(
        _ label: LocalizedStringKey, selected: Bool, act: @escaping () -> Void
    ) -> some View {
        Button(action: act) {
            Text(label, bundle: .module)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Neon.ground : Neon.ink)
                .frame(width: 56, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selected ? Neon.ink : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    Neon.ink.opacity(selected ? 1 : 0.4), lineWidth: 1.5)))
        }
        .buttonStyle(.plain)
    }

    /// A destructive action that arms on the first tap and fires on the
    /// second — deliberate without being a popup.
    private func dangerButton(
        armed: Binding<Bool>, idle: LocalizedStringKey, confirm: LocalizedStringKey,
        fire: @escaping () -> Void
    ) -> some View {
        NeonButton(title: armed.wrappedValue ? confirm : idle, tint: Neon.magenta) {
            if armed.wrappedValue {
                fire()
                armed.wrappedValue = false
            } else {
                armed.wrappedValue = true
            }
        }
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
}
