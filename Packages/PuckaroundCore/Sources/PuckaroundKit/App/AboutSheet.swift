import PuckaroundCore
import SwiftUI

/// App "About": icon, wordmark, version, and credits — behind the title's
/// "i", the same shape as the sibling apps'.
struct AboutSheet: View {
    let onClose: () -> Void

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    /// The build's git commit (`GitCommitSHA`, injected at build time);
    /// hidden when a build doesn't carry one.
    private var commitSHA: String? {
        Bundle.main.infoDictionary?["GitCommitSHA"] as? String
    }

    /// The author is the same person in two scripts — picked by locale, not
    /// translated by the catalog (the sibling apps' pattern).
    private var authorName: String {
        (Bundle.module.preferredLocalizations.first?.hasPrefix("ja") ?? false)
            ? "三﨑ヴィッレ" : "Ville Misaki"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                // A sideways phone is shorter than the card — scroll there,
                // hug the content wherever it fits.
                HuggingScrollView {
                    content
                        .padding(24)
                }
            }
            .frame(maxWidth: Neon.sheetWidth)
            .background(NeonCard())
            .padding(16)
        }
    }

    private var header: some View {
        NeonSheetHeader(title: "About", onClose: onClose)
    }

    private var content: some View {
        VStack(spacing: 16) {
            appIcon
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(spacing: 0) {
                Text(verbatim: "PUCK")
                    .foregroundStyle(Neon.cyan)
                    .shadow(color: Neon.cyan.opacity(0.7), radius: 8)
                Text(verbatim: "AROUND")
                    .foregroundStyle(Neon.magenta)
                    .shadow(color: Neon.magenta.opacity(0.7), radius: 8)
            }
            .font(.system(size: 24, weight: .black, design: .rounded))
            Text("The device is the table.", bundle: .module)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Neon.inkSoft)
            Text("Version \(versionString)", bundle: .module)
                .font(.footnote.monospaced().weight(.semibold))
                .foregroundStyle(Neon.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().strokeBorder(Neon.inkSoft.opacity(0.5), lineWidth: 1))
            if let sha = commitSHA {
                Text(verbatim: sha)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Neon.inkSoft.opacity(0.7))
            }
            VStack(spacing: 6) {
                Text(verbatim: "© 2026 \(authorName)")
                    .font(.footnote)
                    .foregroundStyle(Neon.inkSoft)
                Link(destination: URL(string: "https://github.com/vlumi/puckaround")!) {
                    Label {
                        Text(verbatim: "github.com/vlumi/puckaround")
                    } icon: {
                        Image(systemName: "link")
                    }
                    .font(.footnote)
                }
                .tint(Neon.cyan)
            }
        }
    }

    /// The app icon, dug out of the bundle (the `AppIcon` set isn't directly
    /// loadable as a UI image). The Kit also compiles on macOS for tests,
    /// where a placeholder stands in.
    @ViewBuilder private var appIcon: some View {
        #if os(iOS)
        if let ui = uiAppIcon {
            Image(uiImage: ui).resizable()
        } else {
            placeholderIcon
        }
        #else
        placeholderIcon
        #endif
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Neon.inkSoft.opacity(0.2))
    }

    #if os(iOS)
    private var uiAppIcon: UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let name = files.last
        else { return nil }
        return UIImage(named: name)
    }
    #endif
}
