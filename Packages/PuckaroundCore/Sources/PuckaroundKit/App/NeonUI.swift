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
                        .shadow(color: tint.opacity(0.7), radius: prominent ? 12 : 8))
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(Neon.ground.opacity(0.7))
                        .overlay(Circle().strokeBorder(tint.opacity(0.5), lineWidth: 1.5)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label, bundle: .module))
    }
}
