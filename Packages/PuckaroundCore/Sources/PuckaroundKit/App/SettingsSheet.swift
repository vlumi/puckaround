import PuckaroundCore
import SwiftUI

/// **The app's own switches** — not match settings (those live in New match):
/// the feedback toggles, the remembered names, and the destructive resets,
/// behind the title's gear. Resets arm on the first tap and fire on the
/// second — deliberate, without a popup.
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
                NeonSheetHeader(title: "Settings", onClose: onClose)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                // Names can outgrow a screen; the sections scroll as one —
                // and the card hugs them where the screen has room.
                HuggingScrollView {
                    VStack(spacing: 24) {
                        section("Feedback") {
                            toggleRow("Sounds", isOn: $soundOn)
                            toggleRow("Haptics", isOn: $hapticsOn)
                        }
                        // The pool everything draws from — tournaments and
                        // arcade boards alike — so this is where to look for
                        // a name, whichever mode wrote it.
                        section("Names") {
                            PoolManager()
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
            }
            .frame(maxWidth: Neon.sheetWidth)
            .background(NeonCard())
            .padding(16)
        }
    }

    private func toggleRow(_ label: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Text(label, bundle: .module)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Neon.ink)
            Spacer()
            NeonChoicePill(title: "On", selected: isOn.wrappedValue, width: 56) {
                isOn.wrappedValue = true
            }
            NeonChoicePill(title: "Off", selected: !isOn.wrappedValue, width: 56) {
                isOn.wrappedValue = false
            }
        }
    }

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
            NeonCaption(title: key, size: 15)
            body()
        }
    }
}
