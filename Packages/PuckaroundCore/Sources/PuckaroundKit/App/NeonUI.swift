import SwiftUI

/// The menus' look, matched to the cabinet the table lives in: dark ground,
/// neutral neon lines, a glow on the things you touch. Kept tiny — the game is
/// the star, the chrome stays quiet.
enum Neon {
    static let ground = RinkRenderer.ground
    static let ink = RinkRenderer.line
    static let inkSoft = RinkRenderer.line.opacity(0.6)
    static let cyan = SeatPalette.cyan
    static let magenta = SeatPalette.magenta
}

/// A glowing outline button — the primary way to act on a menu.
struct NeonButton: View {
    let title: LocalizedStringKey
    var tint: Color = Neon.ink
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title, bundle: .module)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(prominent ? Neon.ground : tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(prominent ? tint : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).strokeBorder(tint, lineWidth: 2)
                        )
                        .shadow(color: tint.opacity(0.7), radius: prominent ? 12 : 8)
                )
                // The whole pill is the tap target — without this, an outline
                // (non-prominent) button only registers hits on the glyphs, not
                // the empty interior of the rounded rectangle.
                .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

/// A dim, unobtrusive icon button — for the in-game menu affordance that must
/// not compete with play.
struct NeonIconButton: View {
    let systemName: String
    let label: LocalizedStringKey
    var tint: Color = Neon.inkSoft
    /// Filled with the tint instead of outlined — a toggle's ON state.
    var solid = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(solid ? Neon.ground : tint)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(solid ? tint : Neon.ground.opacity(0.7))
                        .overlay(Circle().strokeBorder(tint.opacity(0.5), lineWidth: 1.5)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label, bundle: .module))
    }
}

/// The solid card the menus sit on — near-opaque ground with a soft outline, so
/// the glowing table doesn't bleed through the words. One card, every menu.
struct NeonCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18).fill(Neon.ground.opacity(0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 18).strokeBorder(Neon.inkSoft, lineWidth: 1))
    }
}

/// Every sheet's title row — the centered name, the X out, and whatever extra
/// corner button a sheet adds (the arcade shelf's Names). One header for all
/// seven sheets, so the chrome can't drift.
struct NeonSheetHeader<Extra: View>: View {
    let title: LocalizedStringKey
    let onClose: () -> Void
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        ZStack {
            Text(title, bundle: .module)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Neon.ink)
            HStack(spacing: 6) {
                Spacer()
                extra()
                NeonIconButton(systemName: "xmark", label: "Close", action: onClose)
            }
        }
    }
}

extension NeonSheetHeader where Extra == EmptyView {
    init(title: LocalizedStringKey, onClose: @escaping () -> Void) {
        self.init(title: title, onClose: onClose, extra: { EmptyView() })
    }
}

/// The small-caps caption over a section or banner block — one label style
/// across every sheet (11pt banners, 15pt section heads).
struct NeonCaption: View {
    let title: LocalizedStringKey
    var size: CGFloat = 11

    var body: some View {
        Text(title, bundle: .module)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Neon.inkSoft)
            .textCase(.uppercase)
            .kerning(2)
    }
}

/// The pill behind a picker option: filled when selected, outlined when not.
/// `tint` colors it (defaulting to neutral ink for the mono pickers).
struct NeonPillBackground: View {
    var selected: Bool
    var tint: Color = Neon.ink

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(selected ? tint : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tint.opacity(selected ? 1 : 0.4), lineWidth: 1.5))
    }
}

/// A labeled choice pill — the On/Off toggles and format options across the
/// sheets. Flexible width by default; pass `width` to fix it.
struct NeonChoicePill: View {
    let title: LocalizedStringKey
    var selected: Bool
    var width: CGFloat?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title, bundle: .module)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Neon.ground : Neon.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 10)
                .frame(height: 44)
                .frame(maxWidth: width == nil ? .infinity : nil)
                .frame(width: width)
                .background(NeonPillBackground(selected: selected))
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
